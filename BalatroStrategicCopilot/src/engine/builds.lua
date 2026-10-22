-- Balatro Strategic Copilot - engine/builds.lua
-- The synergies of top players' builds (model/builds_db.lua) applied to the current run:
--   * synergies of a joker with the board and the deck (shop: what the joker will become with
--     the pieces already owned, on top of what the score engine measures now);
--   * builds under way (core piece owned), their missing pieces and how to assemble them;
--   * which cards each build wants (tarot / spectral targets: Kings for Baron, figures for
--     Photograph, 2-5 for Hack, the payoff suit for a flush build, figures to destroy for Canio).
-- Early in the run (antes 1-2) synergies count less: top players do not force a build before
-- the shop has offered its pieces ("let the shop decide early, commit around ante 3").
-- Pure functions of the state.

local BSC = BSCopilot
local U = BSC.require('core/util')
local C = BSC.require('model/cards')
local DB = BSC.require('model/jokers_db')
local DBB = BSC.require('model/builds_db')
local PL = BSC.require('engine/plan')

local BD = {}

local function owned_set(state, without)
    local set = {}
    for _, j in ipairs(state.jokers or {}) do
        if j.key and j ~= without then set[j.key] = (set[j.key] or 0) + 1 end
    end
    return set
end

local function name_of(key)
    local d = DB.get(key)
    return (d and d.name) or key
end
BD.name_of = name_of

-- Value of a deck metric of builds_db.DECK.
local function deck_value(state, field, joker_key)
    local st = state.full_deck_stats or {}
    local ranks = st.ranks or {}
    local size = math.max(1, st.size or 52)
    local id = field:match('^rank:(%d+)$')
    if id then return ranks[tonumber(id)] or 0 end
    if field == 'low' then return (ranks[2] or 0) + (ranks[3] or 0) + (ranks[4] or 0) + (ranks[5] or 0) end
    local suits = st.suits or {}
    if field == 'suit_share' then return (suits[DBB.SUIT_OF[joker_key] or ''] or 0) / size end
    if field == 'dark_share' then return ((suits.Spades or 0) + (suits.Clubs or 0)) / size end
    if field == 'small_deck' then return (st.starting_size or 52) - (st.size or 52) end
    return st[field] or 0
end

local function in_list(list, key)
    for _, k in ipairs(list or {}) do if k == key then return true end end
    return false
end

-- Synergies of joker `key` with the board (minus `without`) and the deck.
-- Returns total (potential units, clamped), list of { v, why, with }.
function BD.synergies(key, state, without)
    local own = owned_set(state, without)
    local list, seen = {}, {}
    local S = DBB.STRENGTH
    local function add(v, why, with, tag)
        if tag then if seen[tag] then return end seen[tag] = true end
        list[#list + 1] = { v = v, why = why, with = with }
    end
    for _, p in ipairs(DBB.PAIRS) do
        local other = (p[1] == key and p[2]) or (p[2] == key and p[1]) or nil
        if other and own[other] then add(S[p[3]], p[4], name_of(other), 'pair:' .. other) end
    end
    for _, d in ipairs(DBB.DECK) do
        if d[1] == key and deck_value(state, d[2], key) >= d[3] then add(S[d[4]], d[5], nil, 'deck:' .. d[2]) end
    end
    local kind = PL.joker_kind(DB.get(key))
    if DBB.COPIERS[key] then
        -- a copy joker wants an xMult or retrigger target
        for _, j in ipairs(state.jokers or {}) do
            if j ~= without and not DBB.COPIERS[j.key] and not seen['pair:' .. tostring(j.key)] then
                local k = PL.joker_kind(DB.get(j.key, j.name))
                if k == 'xmult' or k == 'retrigger' then add(S.A, 'copie un multiplicateur', j.name or name_of(j.key), 'copy'); break end
            end
        end
    elseif kind == 'xmult' or kind == 'retrigger' then
        for ck in pairs(DBB.COPIERS) do
            if own[ck] and not seen['pair:' .. ck] then add(S.B, 'copiable par ' .. name_of(ck), name_of(ck), 'copied') end
        end
    end
    -- builds: support of a build under way, core piece of a build whose support is there,
    -- anti-synergy with a build under way
    for _, b in ipairs(DBB.BUILDS) do
        local core_owned, support_owned = 0, 0
        for _, k in ipairs(b.core) do if own[k] then core_owned = core_owned + 1 end end
        for _, k in ipairs(b.support) do if own[k] then support_owned = support_owned + 1 end end
        if core_owned > 0 and in_list(b.support, key) and not in_list(b.core, key) then
            add(S.C, 'pièce du build « ' .. b.name .. ' »', nil, 'build:' .. b.key)
        end
        if in_list(b.core, key) and support_owned >= 2 then
            add(S.B, 'complète le build « ' .. b.name .. ' »', nil, 'build:' .. b.key)
        end
        if core_owned > 0 and in_list(b.anti, key) then
            local pair_counted = false
            for _, k in ipairs(b.core) do if seen['pair:' .. k] then pair_counted = true end end
            if not pair_counted then add(S.X, 'contraire au build « ' .. b.name .. ' »', nil, 'anti:' .. b.key) end
        end
    end
    local total = 0
    for _, e in ipairs(list) do total = total + e.v end
    return U.clamp(total, -0.5, 0.6), list
end

-- Shop bonus of a joker (potential units) and the reason shown.
function BD.joker_bonus(key, state, without)
    if not key then return 0, nil end
    local total, list = BD.synergies(key, state, without)
    if total == 0 then return 0, nil end
    -- "synergie avec mes jokers": the player's corrections make the synergies weigh more
    local lr = BSC.learning_runtime
    local fbp = lr and lr.player_feedback and lr.player_feedback()
    if fbp and total > 0 then total = total * (BSC.require('learning/feedback').nudges(fbp).synergy or 1) end
    local ante = (state.run and state.run.ante) or 1
    -- do not force a build before the shop has offered its pieces
    if total > 0 and ante <= 2 then total = total * 0.7 end
    table.sort(list, function(a, b) return math.abs(a.v) > math.abs(b.v) end)
    local e = list[1]
    local why
    if e then
        why = ((e.v < 0) and 'anti-synergie : ' or 'synergie : ') .. (e.with and (e.with .. ', ') or '') .. e.why
    end
    return total, why, list
end

-- Builds under way (a core piece owned), most advanced first:
-- { key, name, tier, have = {names}, missing = {names}, progress, tip, hands }
function BD.active(state)
    local own = owned_set(state)
    local out = {}
    for _, b in ipairs(DBB.BUILDS) do
        local have, missing = {}, {}
        local core = 0
        for _, k in ipairs(b.core) do if own[k] then core = core + 1; have[#have + 1] = name_of(k) end end
        if core > 0 then
            local sup = 0
            for _, k in ipairs(b.support) do
                if own[k] then sup = sup + 1; have[#have + 1] = name_of(k)
                elseif #missing < 3 then missing[#missing + 1] = name_of(k) end
            end
            out[#out + 1] = { key = b.key, name = b.name, tier = b.tier, have = have, missing = missing,
                progress = core + 0.5 * sup, tip = b.tip, hands = b.hands, def = b }
        end
    end
    table.sort(out, function(a, b) return a.progress > b.progress end)
    return out
end

-- Suit of the suit payoff jokers owned (the most represented), or nil.
function BD.payoff_suit(state)
    local count = {}
    for _, j in ipairs(state.jokers or {}) do
        local s = DBB.SUIT_OF[j.key]
        if s then count[s] = (count[s] or 0) + 1 end
    end
    local best, bn = nil, 0
    for s, n in pairs(count) do if n > bn or (n == bn and tostring(s) < tostring(best)) then best, bn = s, n end end
    return best
end

-- Canio: figures are worth DESTROYING (each one: +x1 Mult for good).
function BD.destroy_faces(state)
    for _, j in ipairs(state.jokers or {}) do if j.key == 'j_caino' and not j.debuff then return true end end
    return false
end

-- How much the builds under way want a card (added to the usefulness of tarot targets).
-- Returns a function(card) -> bonus.
function BD.card_bonus(state, rules)
    local builds = BD.active(state)
    local suit = BD.payoff_suit(state)
    return function(c)
        if not c or c.face_down then return 0 end
        local v = 0
        for _, b in ipairs(builds) do
            local d = b.def
            if d.ranks and c.id then v = v + (d.ranks[c.id] or 0) end
            if d.faces and C.is_face(c, rules) then v = v + d.faces end
            if d.suit == 'payoff' and suit and c.suit == suit then v = v + 8 end
        end
        return v
    end
end

return BD
