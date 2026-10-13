local T = ...
local S = {}

local function store(clock)
    local P = BSCopilot.require('io/persistence')
    local t = clock or 1000
    local be = P.memory_backend()
    local st = P.new(be, { now = function() t = t + 1; return t end })
    st:init()
    return st, be, P
end

function S.save_and_load_roundtrip(T)
    local st = store()
    T.ok(st:save('profile', 1, { runs = 3, name = 'é' }))
    local P = BSCopilot.require('io/persistence')
    local st2 = P.new(st.be)
    local data, info = st2:load('profile', 1, function() return { runs = 0 } end)
    T.eq(data.runs, 3); T.eq(data.name, 'é'); T.eq(info.seq, 1)
end

function S.alternating_slots_survive_interrupted_write(T)
    local st, be = store()
    st:save('doc', 1, { v = 1 })
    st:save('doc', 1, { v = 2 })
    -- third save is interrupted halfway (truncated file in the slot being written)
    be.fail = 'truncate'
    local ok = st:save('doc', 1, { v = 3 })
    T.no(ok)
    be.fail = nil
    local P = BSCopilot.require('io/persistence')
    local st2 = P.new(be)
    local data, info = st2:load('doc', 1, function() return { v = 0 } end)
    T.eq(data.v, 2, 'last good version recovered')
    T.ok(info.recovered, 'damaged slot detected')
    -- the damaged file was quarantined, not silently lost
    local q = 0
    for k in pairs(be.files) do if k:find('BSC/corrupt/') then q = q + 1 end end
    T.eq(q, 1)
end

function S.corruption_detected_by_checksum(T)
    local st, be = store()
    st:save('doc', 1, { v = 'ok' })
    -- flip a character inside the payload without breaking JSON syntax
    local path = 'BSC/doc.a.json'
    be.files[path] = be.files[path]:gsub('ok', 'ko', 1)
    local P = BSCopilot.require('io/persistence')
    local data, info = P.new(be):load('doc', 1, function() return { v = 'default' } end)
    T.eq(data.v, 'default'); T.ok(info.recovered)
end

function S.migration_with_backup(T)
    local st, be = store()
    st:save('profile', 1, { runs = 2 })
    local P = BSCopilot.require('io/persistence')
    local st2 = P.new(be, { now = function() return 5000 end })
    local data, info = st2:load('profile', 2, function() return {} end, { [1] = function(d) d.new_field = 'x'; return d end })
    T.eq(data.new_field, 'x'); T.eq(data.runs, 2); T.ok(info.migrated)
    local backups = 0
    for k in pairs(be.files) do if k:find('BSC/backups/profile.v1') then backups = backups + 1 end end
    T.eq(backups, 1)
    -- reloading gives the migrated version without migrating again
    local data2, info2 = P.new(be):load('profile', 2, function() return {} end, {})
    T.eq(data2.new_field, 'x'); T.no(info2.migrated)
end

function S.newer_schema_is_never_overwritten(T)
    local st, be = store()
    st:save('profile', 9, { future = true })
    local P = BSCopilot.require('io/persistence')
    local st2 = P.new(be)
    local data, info = st2:load('profile', 2, function() return {} end)
    T.ok(info.newer)
    T.no(st2:save('profile', 2, { downgrade = true }))
    local data3 = P.new(be):load('profile', 9, function() return {} end)
    T.ok(data3.future)
end

function S.export_import_reset_files(T)
    local st, be = store()
    local path = st:export({ profile = { runs = 1 }, runs = { { id = 'r1' } } })
    T.ok(path and be.files[path])
    -- move export into import folder and read it back
    be.files['BSC/import/x.json'] = be.files[path]
    be.files['BSC/import/bad.json'] = 'not json'
    local bundles, bad = st:read_imports()
    T.eq(#bundles, 1); T.eq(#bad, 1)
    T.eq(bundles[1].bundle.runs[1].id, 'r1')
    st:mark_imported(bundles[1].path)
    T.eq(be.files['BSC/import/x.json'], nil)
end

function S.log_rotation(T)
    local st, be = store()
    for i = 1, 200 do st:append_log(string.rep('x', 50), 2000) end
    T.ok(#be.files['BSC/logs/bsc.log'] <= 2100)
    T.ok(be.files['BSC/logs/bsc.old.log'])
end

function S.data_files_are_not_executed(T)
    local st, be = store()
    _G.__bsc_exec = nil
    be.files['BSC/evil.a.json'] = 'return (function() _G.__bsc_exec = true end)()'
    local P = BSCopilot.require('io/persistence')
    local data = P.new(be):load('evil', 1, function() return { safe = true } end)
    T.ok(data.safe); T.eq(_G.__bsc_exec, nil)
end

return S
