-- Balatro Strategic Copilot - io/persistence.lua  (PersistenceManager)
-- Local, offline, versioned storage in the LÖVE save directory (%AppData%/Balatro/BSC/).
-- Crash safety without atomic rename (love.filesystem has none):
--   each document is written alternately to two slots (<name>.a.json / <name>.b.json) inside an
--   envelope { format, schema, seq, length, checksum, saved_at, data }. Loading validates both
--   slots (JSON, length, Adler-32 checksum) and keeps the highest valid sequence number, so an
--   interrupted write can only ever damage the slot being written, never the last good copy.
-- Corrupted files are moved to corrupt/ (never silently deleted). Schema migrations run step
-- by step after a backup copy. Data files are parsed as JSON only (never executed).

local BSC = BSCopilot
local U = BSC.require('core/util')
local J = BSC.require('core/json')

local P = {}
P.__index = P

P.ROOT = 'BSC'
P.FORMAT = 'bsc-copilot'

local function adler32(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end
P.adler32 = adler32

-- Backends -----------------------------------------------------------------------------------

function P.love_backend()
    local fs = love and love.filesystem
    assert(fs, 'love.filesystem unavailable')
    return {
        read = function(path)
            local info = fs.getInfo(path)
            if not info then return nil end
            local data = fs.read(path)
            return data
        end,
        write = function(path, data) return fs.write(path, data) end,
        append = function(path, data)
            if fs.append then return fs.append(path, data) end
            local old = fs.read(path) or ''
            return fs.write(path, old .. data)
        end,
        exists = function(path) return fs.getInfo(path) ~= nil end,
        size = function(path) local i = fs.getInfo(path); return i and i.size or 0 end,
        mkdir = function(path) return fs.createDirectory(path) end,
        remove = function(path) return fs.remove(path) end,
        list = function(dir) return fs.getDirectoryItems(dir) or {} end,
        real_dir = function() return fs.getSaveDirectory and fs.getSaveDirectory() or '?' end,
    }
end

-- In-memory backend for tests; `fail` lets tests simulate interrupted/failed writes.
function P.memory_backend()
    local files = {}
    local be = { files = files, fail = nil }
    be.read = function(path) return files[path] end
    be.write = function(path, data)
        if be.fail then
            local mode = be.fail
            if mode == 'truncate' then files[path] = data:sub(1, math.floor(#data / 2)) end
            if mode == 'error' then return false, 'simulated failure' end
            return false, 'simulated failure'
        end
        files[path] = data
        return true
    end
    be.append = function(path, data) files[path] = (files[path] or '') .. data; return true end
    be.exists = function(path)
        if files[path] then return true end
        for k in pairs(files) do if k:sub(1, #path + 1) == path .. '/' then return true end end
        return be.dirs and be.dirs[path] or false
    end
    be.size = function(path) return files[path] and #files[path] or 0 end
    be.dirs = {}
    be.mkdir = function(path) be.dirs[path] = true; return true end
    be.remove = function(path) files[path] = nil; return true end
    be.list = function(dir)
        local out, seen = {}, {}
        for k in pairs(files) do
            if k:sub(1, #dir + 1) == dir .. '/' then
                local rest = k:sub(#dir + 2)
                local name = rest:match('^([^/]+)')
                if name and not seen[name] then seen[name] = true; out[#out + 1] = name end
            end
        end
        table.sort(out)
        return out
    end
    be.real_dir = function() return 'memory' end
    return be
end

-- Store --------------------------------------------------------------------------------------

function P.new(backend, opts)
    local self = setmetatable({}, P)
    self.be = backend
    self.opts = opts or {}
    self.seq = {}         -- name -> last sequence number
    self.readonly = {}    -- name -> true when a newer schema was found
    self.errors = {}
    self.now = self.opts.now or os.time
    return self
end

function P:path(...)
    return table.concat({ P.ROOT, ... }, '/')
end

function P:init()
    for _, d in ipairs({ '', 'runs', 'backups', 'corrupt', 'export', 'import', 'logs' }) do
        local p = d == '' and P.ROOT or self:path(d)
        if not self.be.exists(p) then self.be.mkdir(p) end
    end
    return true
end

local function slot_paths(self, name)
    return self:path(name .. '.a.json'), self:path(name .. '.b.json')
end

-- Validate one stored file. Returns envelope or nil, reason.
function P:validate(text)
    if type(text) ~= 'string' or #text == 0 then return nil, 'empty' end
    local env, err = J.try_decode(text)
    if type(env) ~= 'table' then return nil, 'json: ' .. tostring(err) end
    if env.format ~= P.FORMAT then return nil, 'format' end
    if type(env.payload) ~= 'string' then return nil, 'payload' end
    if #env.payload ~= env.length then return nil, 'length' end
    if adler32(env.payload) ~= env.checksum then return nil, 'checksum' end
    local data, derr = J.try_decode(env.payload)
    if data == nil then return nil, 'payload json: ' .. tostring(derr) end
    env.data = data
    return env
end

function P:quarantine(path, reason)
    local text = self.be.read(path)
    if text then
        local q = self:path('corrupt', (path:gsub('[/\\]', '_')) .. '.' .. tostring(self.now()) .. '.txt')
        self.be.write(q, '# reason: ' .. tostring(reason) .. '\n' .. text)
    end
    self.be.remove(path)
    self.errors[#self.errors + 1] = { path = path, reason = reason }
end

-- Save a document (data must be JSON-serializable). Returns true or false, err.
function P:save(name, schema, data)
    if self.readonly[name] then return false, 'readonly (newer schema on disk)' end
    local ok_enc, payload = pcall(J.encode, data)
    if not ok_enc then return false, 'encode: ' .. tostring(payload) end
    local seq = (self.seq[name] or 0) + 1
    local env = { format = P.FORMAT, schema = schema, seq = seq, length = #payload,
        checksum = adler32(payload), saved_at = self.now(), payload = payload }
    local text = J.encode(env)
    local a, b = slot_paths(self, name)
    local target = (seq % 2 == 1) and a or b
    local ok, err = self.be.write(target, text)
    if not ok then return false, err or 'write failed' end
    -- verify read-back
    local back = self.be.read(target)
    if back ~= text then return false, 'verification failed' end
    self.seq[name] = seq
    return true
end

-- Load a document. migrations[v] = function(data) -> data for v -> v+1.
-- Returns data, info = { schema, seq, source, recovered, migrated }.
function P:load(name, schema, default_factory, migrations)
    local a, b = slot_paths(self, name)
    local best, best_path
    local info = { recovered = false, migrated = false }
    for _, p in ipairs({ a, b }) do
        local text = self.be.read(p)
        if text then
            local env, reason = self:validate(text)
            if env then
                if not best or env.seq > best.seq then best, best_path = env, p end
            else
                info.recovered = true
                self:quarantine(p, reason)
            end
        end
    end
    if not best then
        self.seq[name] = self.seq[name] or 0
        return default_factory(), info
    end
    self.seq[name] = best.seq
    info.schema, info.seq, info.source = best.schema, best.seq, best_path
    local data = best.data
    local v = best.schema or 1
    if v > schema then
        self.readonly[name] = true
        info.newer = true
        return data, info
    end
    if v < schema then
        -- backup before migrating
        self.be.write(self:path('backups', name .. '.v' .. v .. '.' .. tostring(self.now()) .. '.json'), self.be.read(best_path) or '')
        while v < schema do
            local m = migrations and migrations[v]
            if not m then return default_factory(), info end
            local ok, res = pcall(m, data)
            if not ok or res == nil then
                info.migration_error = tostring(res)
                return default_factory(), info
            end
            data = res
            v = v + 1
        end
        info.migrated = true
        self:save(name, schema, data)
    end
    return data, info
end

function P:exists(name)
    local a, b = slot_paths(self, name)
    return self.be.exists(a) or self.be.exists(b)
end

function P:delete(name)
    local a, b = slot_paths(self, name)
    self.be.remove(a); self.be.remove(b)
    self.seq[name] = nil
end

function P:backup(name, tag)
    local a, b = slot_paths(self, name)
    for _, p in ipairs({ a, b }) do
        local text = self.be.read(p)
        if text then
            local fname = (p:match('([^/]+)$') or name) .. '.' .. (tag or 'backup') .. '.' .. tostring(self.now())
            self.be.write(self:path('backups', fname), text)
        end
    end
end

-- Log file with size cap (rotation keeps one previous file).
function P:append_log(line, max_bytes)
    local path = self:path('logs', 'bsc.log')
    if self.be.size(path) > (max_bytes or 524288) then
        local old = self.be.read(path) or ''
        self.be.write(self:path('logs', 'bsc.old.log'), old)
        self.be.write(path, '')
    end
    self.be.append(path, line .. '\n')
end

-- Export everything into one JSON file. Returns the path.
function P:export(bundle)
    local name = 'bsc_export_' .. os.date('%Y%m%d_%H%M%S', self.now()) .. '.json'
    local path = self:path('export', name)
    local doc = { format = P.FORMAT .. '-export', exported_at = self.now(), bundle = bundle }
    local ok, err = self.be.write(path, J.encode(doc, true))
    if not ok then return nil, err end
    return path
end

-- Read every file in import/ ; returns list of bundles (invalid files are reported).
function P:read_imports()
    local out, bad = {}, {}
    local dir = self:path('import')
    for _, fname in ipairs(self.be.list(dir)) do
        local p = dir .. '/' .. fname
        local text = self.be.read(p)
        local doc = text and J.try_decode(text)
        if type(doc) == 'table' and doc.format == P.FORMAT .. '-export' and type(doc.bundle) == 'table' then
            out[#out + 1] = { path = p, bundle = doc.bundle }
        else
            bad[#bad + 1] = p
        end
    end
    return out, bad
end

function P:mark_imported(path)
    local text = self.be.read(path)
    if text then
        self.be.write(self:path('backups', 'imported_' .. (path:match('([^/]+)$') or 'file')), text)
        self.be.remove(path)
    end
end

return P
