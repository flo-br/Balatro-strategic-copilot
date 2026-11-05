-- Balatro Strategic Copilot - tools/trainer/options.lua
-- key=value options shared by run.lua and branch.lua: simulator options (deck, stake, learn),
-- experiment switches of the engine (docs/TRAINING.md, "Résultats 1.0.10"), compute settings
-- (rollouts, shop_samples...) and any setting of the advice section of config.lua.
-- Returns the options it did not recognise as engine settings in opts.extra (key -> value).
local O = {}

local SWITCHES = {
    track_scale = { 'engine/plan', 'TRACK_SCALE', 'number' },
    hs_rules = { 'engine/plan', 'HIGH_STAKE_RULES', 'bool' },
    xmult_extra = { 'engine/plan', 'XMULT_EXTRA', 'number' },
    future_blend = { 'engine/shop', 'FUTURE_BLEND', 'number' },
    main_focus = { 'engine/shop', 'MAIN_FOCUS', 'number' },
    sample_growth = { 'engine/shop', 'SAMPLE_GROWTH', 'bool' },
    replace_growth = { 'engine/shop', 'REPLACE_GROWTH', 'bool' },
    hs_power = { 'engine/shop', 'HS_POWER', 'number' },
    pack_free = { 'engine/shop', 'PACK_JOKERS_FREE', 'bool' },
    pack_penalty = { 'engine/shop', 'PACK_PENALTY', 'number' },
    prior_cal = { 'engine/shop', 'PRIOR_CALIBRATION', 'bool' },
    hidden_discards = { 'engine/hand_advisor', 'HIDDEN_DISCARDS', 'bool' },
    syn_list = { 'engine/builds', 'LIST_SCALE', 'number' },
    syn_items = { 'engine/builds', 'ITEM_SCALE', 'number' },
    syn_generic = { 'engine/builds', 'GENERIC_SCALE', 'number' },
    syn_static = { 'engine/builds', 'STATIC_SCALE', 'number' },
    -- 1.1: the weights of the shop note (engine/shop.lua, SH.DEFAULT_WEIGHTS)
    w_impact = { 'engine/shop', 'DEFAULT_WEIGHTS.impact', 'number' },
    w_impact_danger = { 'engine/shop', 'DEFAULT_WEIGHTS.impact_danger', 'number' },
    w_power = { 'engine/shop', 'DEFAULT_WEIGHTS.power', 'number' },
    w_potential = { 'engine/shop', 'DEFAULT_WEIGHTS.potential', 'number' },
    w_synergy = { 'engine/shop', 'DEFAULT_WEIGHTS.synergy', 'number' },
    w_econ = { 'engine/shop', 'DEFAULT_WEIGHTS.econ', 'number' },
    w_cost = { 'engine/shop', 'DEFAULT_WEIGHTS.cost', 'number' },
    w_cost_floor = { 'engine/shop', 'DEFAULT_WEIGHTS.cost_floor', 'number' },
    w_risk = { 'engine/shop', 'DEFAULT_WEIGHTS.risk', 'number' },
    eternal_early = { 'engine/shop', 'ETERNAL_EARLY', 'bool' },
    econ_early = { 'engine/plan', 'ECON_EARLY', 'number' },
    additive_mid = { 'engine/plan', 'ADDITIVE_MID', 'number' },
    additive_full_at = { 'engine/plan', 'ADDITIVE_FULL_AT', 'number' },
    overstock_ante = { 'model/items_db', 'VOUCHERS.v_overstock_norm.per_ante', 'number' },
    overstock2_ante = { 'model/items_db', 'VOUCHERS.v_overstock_plus.per_ante', 'number' },
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
            -- (num may be false: no "x and x or y" below)
            local val = v
            if num ~= nil then val = num end
            if own and own[k] then opts.extra[k] = val
            elseif k == 'deck' then opts.deck = v
            elseif sw then
                local val = num
                if sw[3] == 'bool' then val = (num == 1 or num == true) end
                -- a dotted field name sets a field of a table of the module
                local t, field = BSCopilot.require(sw[1]), sw[2]
                while true do
                    local head, rest = field:match('^([^.]+)%.(.+)$')
                    if not head then break end
                    t, field = t[head], rest
                end
                t[field] = val
            elseif k == 'stake' then opts.stake = tonumber(v)
            elseif k == 'learn' then
                -- learn=1: lessons + settings; learn=lessons / learn=adapt: one mechanism only
                opts.learn = (v == '1' or v == 'true' or v == 'lessons' or v == 'adapt')
                opts.learn_lessons = opts.learn and v ~= 'adapt'
                opts.learn_adapt = opts.learn and v ~= 'lessons'
            elseif cfg.compute[k] ~= nil then cfg.compute[k] = num
            else cfg.advice[k] = val end
        end
    end
    return opts
end

return O
