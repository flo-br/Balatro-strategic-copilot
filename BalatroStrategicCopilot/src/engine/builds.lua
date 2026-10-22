-- Balatro Strategic Copilot - engine/builds.lua
-- The synergies of top players' builds (model/builds_db.lua) and the big list of synergies
-- (model/synergies_db.lua, 1.0.12) applied to the current run:
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
local SDB = BSC.require('model/synergies_db')
local IT = BSC.require('model/items_db')
local I = BSC.require('core/i18n')
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

-- Weight of the 1.0.12 list (model/synergies_db.lua: pairs, items) and of the generic rules,
-- relative to the builds_db pairs (simulator A/B: docs/TRAINING.md; 0 = shown, never counted).
BD.LIST_SCALE = 1
BD.ITEM_SCALE = 1
-- The score engine already MEASURES what two jokers do together now (Blueprint + The Duo, Jolly
-- + Sly, The Chariot with Steel Joker: simulated). A synergy of the 1.0.12 list counts in the note
-- only for what that measurement cannot see: a piece that grows, earns money, generates cards or
-- changes the deck later ("future" piece), or an item whose effect is not simulated. The others
-- are shown (reasons, "Synergies à chercher", docs/SYNERGIES.md) with this weight (measured on
-- the simulator: counting them all did -0.33 +- 0.32 blind per run, docs/TRAINING.md).
BD.STATIC_SCALE = 0
-- generic rules (same hand, same suit...): static by nature, shown only by default
BD.GENERIC_SCALE = 0

-- tags of model/jokers_db.lua whose value depends on what comes later
local FUTURE_TAGS = { scaling = true, decaying = true, econ = true, money = true, permanent = true, tarots = true,
    planets = true, skips = true, tarot_gen = true, spectral_gen = true, joker_gen = true, tag_gen = true, deck_add = true,
    deck_copy = true, add_cards = true, consumable_dup = true, deck_steel = true, deck_stone = true, small_deck = true,
    deck_size = true, enhanced_deck = true, gold = true, glass = true, lucky = true, sell_value = true, levels = true,
    destroys_jokers = true }
local FUTURE_KEYS = { j_supernova = true }
local function future_joker(key)
    if FUTURE_KEYS[key] then return true end
    local d = DB.get(key)
    for _, t in ipairs((d and d.tags) or {}) do if FUTURE_TAGS[t] then return true end end
    return false
end
BD.future_joker = future_joker

local function pair_id(a, b) if a > b then a, b = b, a end return a .. '|' .. b end

-- Joker + joker synergies of both lists, indexed by joker. A pair of both lists keeps its
-- builds_db entry.
BD.PAIRS, BD.PAIRS_OF = {}, {}
do
    local seen = {}
    for li, list in ipairs({ DBB.PAIRS, SDB.PAIRS }) do
        for _, p in ipairs(list) do
            local id = pair_id(p[1], p[2])
            if p[1] ~= p[2] and not seen[id] then
                seen[id] = true
                local e = { a = p[1], b = p[2], tier = p[3], why = p[4], list = (li == 1) and 'builds' or 'synergies',
                    future = future_joker(p[1]) or future_joker(p[2]) }
                BD.PAIRS[#BD.PAIRS + 1] = e
                for _, k in ipairs({ p[1], p[2] }) do
                    local t = BD.PAIRS_OF[k] or {}
                    BD.PAIRS_OF[k] = t
                    t[#t + 1] = e
                end
            end
        end
    end
end

-- Archetypes of both lists
BD.BUILDS = {}
for _, b in ipairs(DBB.BUILDS) do BD.BUILDS[#BD.BUILDS + 1] = b end
for _, b in ipairs(SDB.BUILDS) do BD.BUILDS[#BD.BUILDS + 1] = b end
local function builds() return ((BD.LIST_SCALE or 1) == 0) and DBB.BUILDS or BD.BUILDS end

-- Joker + consumable / voucher / booster synergies, indexed both ways
BD.ITEMS_OF_JOKER, BD.JOKERS_OF_ITEM = {}, {}
-- an item whose effect the shop simulates (tarots that enhance or convert cards, planets, packs,
-- vouchers with a simulated effect) only counts with a "future" joker
local function simulated(item)
    if item == 'planet' or item == 'tarot' or item == 'spectral' or item:match('^pack:') then return true end
    local info = IT.consumable(item) or IT.VOUCHERS[item]
    return (info and info.sim) and true or false
end
for _, p in ipairs(SDB.ITEMS) do
    local e = { joker = p[1], item = p[2], tier = p[3], why = p[4], future = future_joker(p[1]) or not simulated(p[2]) }
    BD.ITEMS_OF_JOKER[p[1]] = BD.ITEMS_OF_JOKER[p[1]] or {}
    table.insert(BD.ITEMS_OF_JOKER[p[1]], e)
    BD.JOKERS_OF_ITEM[p[2]] = BD.JOKERS_OF_ITEM[p[2]] or {}
    table.insert(BD.JOKERS_OF_ITEM[p[2]], e)
end

-- weight counted in the note (shown with DBB.STRENGTH[e.tier] whatever the weight)
local function strength(e)
    if e.list == 'builds' then return DBB.STRENGTH[e.tier] end
    return DBB.STRENGTH[e.tier] * BD.LIST_SCALE * (e.future and 1 or BD.STATIC_SCALE)
end
local function item_strength(e)
    return DBB.STRENGTH[e.tier] * (BD.ITEM_SCALE or 1) * (e.future and 1 or BD.STATIC_SCALE)
end

function BD.item_name(k)
    return SDB.ITEM_NAMES[k] or k
end

-- Keys under which an item is listed: its key, then its class.
function BD.item_classes(it)
    local out = {}
    if it.key then out[#out + 1] = it.key end
    local set = it.set
    if set == 'Planet' then out[#out + 1] = 'planet'
    elseif set == 'Tarot' then out[#out + 1] = 'tarot'
    elseif set == 'Spectral' then out[#out + 1] = 'spectral'
    elseif set == 'Booster' and (it.kind or it.pack_kind) then out[#out + 1] = 'pack:' .. (it.kind or it.pack_kind) end
    return out
end

-- Generic rules: hand types (tags hand_<hand>), suits (suit_<suit>, suit_dark), hands that
-- contain another one (a Three of a Kind contains a Pair: Jolly Joker scores on it).
local CONTAINS = {
    ['Two Pair'] = { Pair = true }, ['Three of a Kind'] = { Pair = true },
    ['Four of a Kind'] = { Pair = true, ['Three of a Kind'] = true },
    ['Straight Flush'] = { Straight = true, Flush = true },
}
local DARK = { Spades = true, Clubs = true }
local VALID = {
    hand = { ['Flush Five'] = true, ['Flush House'] = true, ['Five of a Kind'] = true, ['Straight Flush'] = true,
        ['Four of a Kind'] = true, ['Full House'] = true, Flush = true, Straight = true, ['Three of a Kind'] = true,
        ['Two Pair'] = true, Pair = true, ['High Card'] = true },
    suit = { dark = true },
}
local function tag_set(def, prefix)
    local out = {}
    for _, t in ipairs((def and def.tags) or {}) do
        local v = t:match('^' .. prefix .. '_(.+)$')
        if v and VALID[prefix][v] then out[v] = true end
    end
    return out
end
local function hand_fr(h) return I.hand_name(h) end
local function suit_fr(su) return I.suit_name(su) end

-- returns the strength shown and the reason (counted: strength * BD.GENERIC_SCALE)
local function generic(key, jkey, def, jdef, xm, smeared)
    local g = 1
    local S = DBB.STRENGTH
    local h1, h2 = tag_set(def, 'hand'), tag_set(jdef, 'hand')
    local contained
    for h in pairs(h1) do
        if h2[h] then return (xm and S.A or S.B) * g, 'même main : ' .. hand_fr(h) end
        for o in pairs(h2) do
            if (CONTAINS[o] and CONTAINS[o][h]) or (CONTAINS[h] and CONTAINS[h][o]) then contained = contained or { h, o } end
        end
    end
    -- suits: the suit payoff jokers (builds_db.SUIT_OF; not Seeing Double, which wants a Club
    -- AND another suit) and Blackboard (Spades and Clubs held)
    local su1, su2 = DBB.SUIT_OF[key], DBB.SUIT_OF[jkey]
    local d1, d2 = tag_set(def, 'suit').dark, tag_set(jdef, 'suit').dark
    if su1 and su1 == su2 then return (xm and S.A or S.B) * g, 'même couleur : ' .. suit_fr(su1) end
    if d1 and su2 and DARK[su2] then return S.B * g, 'Blackboard : cartes ' .. suit_fr(su2) end
    if d2 and su1 and DARK[su1] then return S.B * g, 'Blackboard : cartes ' .. suit_fr(su1) end
    -- a suit payoff joker and a Flush joker: a Flush of that suit scores both
    local sf = (su1 and h2.Flush and su1) or (su2 and h1.Flush and su2)
    if sf then return S.C * g, 'une Couleur en ' .. suit_fr(sf) .. ' : les deux marquent' end
    if contained then
        return S.C * g, 'jouer « ' .. hand_fr(contained[2]) .. ' » déclenche aussi « ' .. hand_fr(contained[1]) .. ' »'
    end
    -- two suit payoff jokers of different suits pull the deck two ways (Smeared Joker merges
    -- the suits of the same colour)
    if su1 and su2 and su1 ~= su2 then
        if smeared and (DARK[su1] or false) == (DARK[su2] or false) then
            return S.B * g, 'Smeared Joker : ' .. suit_fr(su1) .. ' et ' .. suit_fr(su2) .. ' comptent ensemble'
        end
        return -S.C * g, 'couleurs différentes (' .. suit_fr(su1) .. ', ' .. suit_fr(su2) .. ') : deux decks à construire'
    end
    return nil
end

-- Synergies of joker `key` with the board (minus `without`), the deck, the vouchers bought and
-- the consumables held. Returns total (potential units, clamped), list of { v, why, with }.
function BD.synergies(key, state, without)
    local own = owned_set(state, without)
    local list, seen = {}, {}
    local S = DBB.STRENGTH
    -- v: counted in the note; d: strength shown (a synergy the score engine measures is shown
    -- with v = 0)
    local function add(v, why, with, tag, d)
        if tag then if seen[tag] then return end seen[tag] = true end
        d = d or v
        if v ~= 0 or d ~= 0 then list[#list + 1] = { v = v, d = d, why = why, with = with } end
    end
    for _, e in ipairs(BD.PAIRS_OF[key] or {}) do
        local other = (e.a == key) and e.b or e.a
        if own[other] then add(strength(e), e.why, name_of(other), 'pair:' .. other, DBB.STRENGTH[e.tier]) end
    end
    for _, d in ipairs(DBB.DECK) do
        if d[1] == key and deck_value(state, d[2], key) >= d[3] then add(S[d[4]], d[5], nil, 'deck:' .. d[2]) end
    end
    local def = DB.get(key)
    local kind = PL.joker_kind(def)
    if DBB.COPIERS[key] then
        -- a copy joker wants an xMult or retrigger target it can copy
        for _, j in ipairs(state.jokers or {}) do
            if j ~= without and not DBB.COPIERS[j.key] and not seen['pair:' .. tostring(j.key)] then
                local jd = DB.get(j.key, j.name)
                local k = PL.joker_kind(jd)
                if (k == 'xmult' or k == 'retrigger') and jd and jd.bp then add(S.A, 'copie un multiplicateur', j.name or name_of(j.key), 'copy'); break end
            end
        end
    elseif (kind == 'xmult' or kind == 'retrigger') and def and def.bp then
        for ck in pairs(DBB.COPIERS) do
            if own[ck] and not seen['pair:' .. ck] then add(S.B, 'copiable par ' .. name_of(ck), name_of(ck), 'copied') end
        end
    end
    -- generic rules with the jokers no pair already links to this one
    local xm = kind == 'xmult'
    for _, j in ipairs(state.jokers or {}) do
        if j ~= without and j.key and j.key ~= key and not seen['pair:' .. j.key] and not seen['gen:' .. j.key] then
            local jd = DB.get(j.key, j.name)
            local d, why = generic(key, j.key, def, jd, xm or PL.joker_kind(jd) == 'xmult', own.j_smeared)
            if d then add(d * (BD.GENERIC_SCALE or 0), why, j.name or name_of(j.key), 'gen:' .. j.key, d) end
        end
    end
    -- vouchers bought and consumables held (Perkeo with Observatory, Baron with a Cryptid held)
    for _, e in ipairs(BD.ITEMS_OF_JOKER[key] or {}) do
        local have = (state.vouchers and state.vouchers[e.item]) and true or false
        if not have and e.item:match('^c_') then
            for _, c in ipairs(state.consumables or {}) do if c.key == e.item then have = true end end
        end
        if have then add(item_strength(e), e.why, BD.item_name(e.item), 'item:' .. e.item, S[e.tier]) end
    end
    -- builds: support of a build under way, core piece of a build whose support is there,
    -- anti-synergy with a build under way
    for _, b in ipairs(builds()) do
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

-- Synergies of a consumable, voucher or booster (shop or pack item `it`: key, set, kind) with
-- the jokers owned (The Chariot with Steel Joker, planets with Constellation, a Standard pack
-- with Hologram, Wasteful with Yorick...). Returns total (potential units), why, list.
function BD.item_bonus(it, state)
    if not it then return 0, nil end
    local own = owned_set(state)
    local list, seen = {}, {}
    for _, cls in ipairs(BD.item_classes(it)) do
        for _, e in ipairs(BD.JOKERS_OF_ITEM[cls] or {}) do
            if own[e.joker] and not seen[e.joker] then
                seen[e.joker] = true
                list[#list + 1] = { v = item_strength(e), d = DBB.STRENGTH[e.tier], why = e.why, with = name_of(e.joker) }
            end
        end
    end
    if #list == 0 then return 0, nil end
    table.sort(list, function(a, b)
        if math.abs(a.v) ~= math.abs(b.v) then return math.abs(a.v) > math.abs(b.v) end
        return math.abs(a.d) > math.abs(b.d)
    end)
    local total = 0
    for _, e in ipairs(list) do total = total + e.v end
    local e = list[1]
    local why = ((e.d < 0) and 'anti-synergie : ' or 'synergie : ') .. e.with .. ', ' .. e.why
    return U.clamp(total, -0.4, 0.5), why, list
end

-- Pieces to look for: the S / A partners (jokers and items) of the jokers owned that are not
-- owned yet, strongest first: { { name, tier, why, with, item = true|nil } }
function BD.wanted(state, max)
    local own = owned_set(state)
    local out, seen = {}, {}
    local rank = { S = 1, A = 2 }
    for k in pairs(own) do
        for _, e in ipairs(BD.PAIRS_OF[k] or {}) do
            local other = (e.a == k) and e.b or e.a
            if rank[e.tier] and not own[other] and not seen[other] then
                seen[other] = true
                out[#out + 1] = { key = other, name = name_of(other), tier = e.tier, why = e.why, with = name_of(k) }
            end
        end
        for _, e in ipairs(BD.ITEMS_OF_JOKER[k] or {}) do
            local have = state.vouchers and state.vouchers[e.item]
            if rank[e.tier] and not have and not seen[e.item] then
                seen[e.item] = true
                out[#out + 1] = { key = e.item, name = BD.item_name(e.item), tier = e.tier, why = e.why, with = name_of(k), item = true }
            end
        end
    end
    table.sort(out, function(a, b)
        if rank[a.tier] ~= rank[b.tier] then return rank[a.tier] < rank[b.tier] end
        if (a.item and 1 or 0) ~= (b.item and 1 or 0) then return not a.item end
        return a.key < b.key
    end)
    local res = {}
    for i = 1, math.min(max or 4, #out) do res[i] = out[i] end
    return res, #out
end

-- Shop bonus of a joker (potential units) and the reason shown.
function BD.joker_bonus(key, state, without)
    if not key then return 0, nil end
    local total, list = BD.synergies(key, state, without)
    if #list == 0 then return 0, nil end
    -- "synergie avec mes jokers": the player's corrections make the synergies weigh more
    local lr = BSC.learning_runtime
    local fbp = lr and lr.player_feedback and lr.player_feedback()
    if fbp and total > 0 then total = total * (BSC.require('learning/feedback').nudges(fbp).synergy or 1) end
    local ante = (state.run and state.run.ante) or 1
    -- do not force a build before the shop has offered its pieces
    if total > 0 and ante <= 2 then total = total * 0.7 end
    table.sort(list, function(a, b)
        if math.abs(a.v) ~= math.abs(b.v) then return math.abs(a.v) > math.abs(b.v) end
        return math.abs(a.d or 0) > math.abs(b.d or 0)
    end)
    local e = list[1]
    local why
    if e then
        why = (((e.d or e.v) < 0) and 'anti-synergie : ' or 'synergie : ') .. (e.with and (e.with .. ', ') or '') .. e.why
    end
    return total, why, list
end

-- Builds under way (a core piece owned), most advanced first:
-- { key, name, tier, have = {names}, missing = {names}, progress, tip, hands }
function BD.active(state)
    local own = owned_set(state)
    local out = {}
    for _, b in ipairs(builds()) do
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
