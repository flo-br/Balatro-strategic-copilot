-- Balatro Strategic Copilot - game/feedback_input.lua  (the "Mon choix" box)
-- Opened with the "my choice" key (config.lua, keys.my_choice, default 'x'). Three screens:
--   1. the choice: what the player highlighted in the game, as choices (buy it, sell it, play
--      these cards, leave the shop...) — a number key;
--   2. the reason: a number key (synergy, x Mult, keep the money...), Enter = no reason;
--   3. a free text (optional, <= 200 characters), Enter saves, Escape goes back.
-- While the box is open, the keyboard goes to the box ONLY: love.keypressed, love.keyreleased
-- and love.textinput (LÖVE callbacks) are wrapped and their events are not passed to the game
-- (typing "r" never reaches the game's restart key). Closed, the wrappers pass everything on.
-- The box never acts in the game: it reads the selection and stores the player's explanation.

local BSC = BSCopilot
local L = BSC.require('core/log')
local FB = BSC.require('learning/feedback')

local FI = { active = nil, hooks = nil }

local function profile()
    local lr = BSC.learning_runtime
    return lr and lr.profile and lr.profile() or nil
end

-- remove the last UTF-8 character
local function backspace(s)
    if s == '' then return s end
    local i = #s
    while i > 1 do
        local b = s:byte(i)
        if b < 0x80 or b >= 0xC0 then break end
        i = i - 1
    end
    return s:sub(1, i - 1)
end
FI.backspace = backspace

local function utf8_len(s)
    local n = 0
    for i = 1, #s do local b = s:byte(i); if b < 0x80 or b >= 0xC0 then n = n + 1 end end
    return n
end

-- Opens the box on the current state. Returns true, or false + reason (shown as an alert).
function FI.open(state, phase, step)
    if FI.active then return true end
    local ctx, why = FB.capture(state, phase, step)
    if not ctx then return false, why end
    FI.active = { stage = 'choice', ctx = ctx, text = '', reason = nil, choice = nil }
    FI.ensure_hooks()
    return true
end

function FI.close() FI.active = nil end

local DIGIT = { ['1'] = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4, ['5'] = 5, ['6'] = 6, ['7'] = 7, ['8'] = 8, ['9'] = 9,
    kp1 = 1, kp2 = 2, kp3 = 3, kp4 = 4, kp5 = 5, kp6 = 6, kp7 = 7, kp8 = 8, kp9 = 9 }

-- Saves the correction (profile, text file) and returns the texts of what was learned.
function FI.save(now)
    local a = FI.active
    if not a or not a.choice then return nil end
    local prof = profile()
    local changes, kept = FB.record(prof, { ctx = a.ctx, choice = a.choice, reason = a.reason, text = a.text }, now)
    local lr = BSC.learning_runtime
    if lr and lr.save_profile then pcall(lr.save_profile) end
    local store = BSC.store
    if kept and store and store.be and store.be.append then
        pcall(function() store.be.append(store:path('mes_choix.txt'), FB.export_line(kept) .. '\n') end)
    end
    FI.active = nil
    FI.last = { changes = changes, entry = kept }
    return changes, kept
end

-- A key while the box is open. Returns true (the key never goes to the game while open).
function FI.keypressed(key)
    local a = FI.active
    if not a then return false end
    if a.stage == 'choice' then
        if key == 'escape' then FI.close(); return true end
        if key == 'delete' then a.stage = 'confirm_reset'; return true end
        local n = DIGIT[key]
        if n and a.ctx.choices[n] then a.choice = a.ctx.choices[n]; a.stage = 'reason' end
        return true
    elseif a.stage == 'reason' then
        if key == 'escape' then a.stage = 'choice'; a.choice = nil; return true end
        if key == 'return' or key == 'kpenter' then a.reason = 'other'; a.stage = 'text'; return true end
        local n = DIGIT[key]
        if n and FB.REASONS[n] then a.reason = FB.REASONS[n].key; a.stage = 'text' end
        return true
    elseif a.stage == 'confirm_reset' then
        if key == 'return' or key == 'kpenter' then
            FB.reset(profile())
            local lr = BSC.learning_runtime
            if lr and lr.save_profile then pcall(lr.save_profile) end
            FI.active = nil
            if FI.on_saved then pcall(FI.on_saved, { 'préférences effacées' }) end
        elseif key == 'escape' then a.stage = 'choice' end
        return true
    elseif a.stage == 'text' then
        if key == 'escape' then a.stage = 'reason'; return true end
        if key == 'return' or key == 'kpenter' then
            local changes = FI.save()
            if FI.on_saved then pcall(FI.on_saved, changes) end
            return true
        end
        if key == 'backspace' then a.text = backspace(a.text) end
        return true
    end
    return true
end

function FI.textinput(t)
    local a = FI.active
    if not a then return false end
    if a.stage == 'text' and type(t) == 'string' and utf8_len(a.text) + utf8_len(t) <= FB.MAX_TEXT then
        a.text = a.text .. t:gsub('[%c]', '')
    end
    return true
end

-- Wraps the LÖVE keyboard callbacks once (again if something replaced them since).
function FI.ensure_hooks()
    if not love then return end
    local h = FI.hooks or {}
    FI.hooks = h
    for _, name in ipairs({ 'keypressed', 'keyreleased', 'textinput' }) do
        local cur = love[name]
        if not (h[name] and cur == h[name].wrapper) then
            local orig = cur
            local wrapper
            wrapper = function(...)
                if FI.active then
                    local ok, err = pcall(function(...)
                        if name == 'keypressed' then FI.keypressed(...) elseif name == 'textinput' then FI.textinput(...) end
                    end, ...)
                    if not ok then L.error('feedback', '%s', tostring(err)); FI.close() end
                    return
                end
                if orig then return orig(...) end
            end
            h[name] = { wrapper = wrapper, orig = orig }
            love[name] = wrapper
        end
    end
end

-- Lines of the box (drawn by ui/ui_manager.lua): { title, lines = {{ {t,c}, ... }} }
function FI.model()
    local a = FI.active
    if not a then return nil end
    local seg = function(t, c) return { t = t, c = c or 'text' } end
    local lines = {}
    local adv = a.ctx.advice
    if adv then
        local t = 'Conseil du copilote : ' .. tostring(adv.label or '') .. ' — ' .. tostring(adv.text or '')
        if adv.cards then t = t .. ' ' .. table.concat(adv.cards, ' ') end
        lines[#lines + 1] = { seg(t, 'dim') }
    end
    if a.stage == 'choice' then
        lines[#lines + 1] = { seg('Votre choix (touche) :', 'title') }
        for i, c in ipairs(a.ctx.choices) do
            if i > 9 then break end
            lines[#lines + 1] = { seg('  ' .. i .. '  ', 'accent'), seg(c.label, 'text') }
        end
        lines[#lines + 1] = { seg('Sélectionnez d\'abord dans le jeu (clic) ce que vous choisiriez. Échap : fermer · Suppr : effacer ce que j\'ai appris de vos choix', 'dim') }
    elseif a.stage == 'confirm_reset' then
        lines[#lines + 1] = { seg('Effacer tout ce que j\'ai appris de vos choix ? (les notes reviennent à mes calculs ; le fichier mes_choix.txt est gardé)', 'mid') }
        lines[#lines + 1] = { seg('Entrée : effacer · Échap : retour', 'dim') }
    elseif a.stage == 'reason' then
        lines[#lines + 1] = { seg('Mon choix : ', 'title'), seg(a.choice.label, 'good') }
        lines[#lines + 1] = { seg('Pourquoi ? (touche)', 'title') }
        for i, r in ipairs(FB.REASONS) do lines[#lines + 1] = { seg('  ' .. i .. '  ', 'accent'), seg(r.label, 'text') } end
        lines[#lines + 1] = { seg('Entrée : sans raison · Échap : retour', 'dim') }
    else
        lines[#lines + 1] = { seg('Mon choix : ', 'title'), seg(a.choice.label, 'good') }
        lines[#lines + 1] = { seg('Raison : ', 'title'), seg(FB.REASON_LABEL[a.reason] or '-', 'text') }
        lines[#lines + 1] = { seg('Expliquez (facultatif) :', 'title') }
        lines[#lines + 1] = { seg('> ' .. a.text .. '_', 'accent') }
        lines[#lines + 1] = { seg('Entrée : enregistrer · Échap : retour · le jeu ne reçoit pas ces touches', 'dim') }
    end
    return { title = 'MON CHOIX (au lieu du conseil)', lines = lines }
end

return FI
