-- Balatro Strategic Copilot - tools/trainer/options.lua
-- key=value options shared by run.lua and branch.lua: simulator options (deck, stake, learn),
-- experiment switches of the engine (docs/TRAINING.md, "Résultats 1.0.10"), compute settings
-- (rollouts, shop_samples...) and any setting of the advice section of config.lua.
-- Returns the options it did not recognise as engine settings in opts.extra (key -> value).
local O = {}

local SWITCHES = {
    track_scale = { 'engine/plan', 'TRACK_SCALE', 'number' },
    hs_rules = { 'engine/plan', 'HIGH_STAKE_RULES', 'bool' },
    future_blend = { 'engine/shop', 'FUTURE_BLEND', 'number' },
    main_focus = { 'engine/shop', 'MAIN_FOCUS', 'number' },
    sample_growth = { 'engine/shop', 'SAMPLE_GROWTH', 'bool' },
    replace_growth = { 'engine/shop', 'REPLACE_GROWTH', 'bool' },
    hs_power = { 'engine/shop', 'HS_POWER', 'number' },
    pack_free = { 'engine/shop', 'PACK_JOKERS_FREE', 'bool' },
    pack_penalty = { 'engine/shop', 'PACK_PENALTY', 'number' },
    prior_cal = { 'engine/shop', 'PRIOR_CALIBRATION', 'bool' },
    hidden_discards = { 'engine/hand_advisor', 'HIDDEN_DISCARDS', 'bool' },
}

-- args: list of strings; cfg: config.lua table; opts: simulator options (modified)
function O.apply(args, from, cfg, opts, own)
    opts.extra = opts.extra or {}
    for i = from, #args do
        local k, v = args[i]:match('^([%w_]+)=(.+)$')
        if k then
            local num = tonumber(v)
            if v == 'true' then num = true elseif v == 'false' then num = false end
            local sw = SWITCHES[k]
            if own and own[k] then opts.extra[k] = (num ~= nil) and num or v
            elseif k == 'deck' then opts.deck = v
            elseif sw then
                local val = num
                if sw[3] == 'bool' then val = (num == 1 or num == true) end
                BSCopilot.require(sw[1])[sw[2]] = val
            elseif k == 'stake' then opts.stake = tonumber(v)
            elseif k == 'learn' then
                -- learn=1: lessons + settings; learn=lessons / learn=adapt: one mechanism only
                opts.learn = (v == '1' or v == 'true' or v == 'lessons' or v == 'adapt')
                opts.learn_lessons = opts.learn and v ~= 'adapt'
                opts.learn_adapt = opts.learn and v ~= 'lessons'
            elseif cfg.compute[k] ~= nil then cfg.compute[k] = num
            else cfg.advice[k] = (num ~= nil) and num or v end
        end
    end
    return opts
end

return O
