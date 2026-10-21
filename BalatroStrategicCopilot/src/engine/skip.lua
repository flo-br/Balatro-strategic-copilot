-- Balatro Strategic Copilot - engine/skip.lua
-- Skip or play a Small / Big Blind (docs/PRO_LESSONS.md §4, sources in
-- docs/PRO_LESSONS_SOURCES.md). Top players weigh the TAG against what the skip really costs,
-- in the current situation:
--   cost  = blind reward ($0 for the Small Blind from Red Stake) + $1 per hand left unused
--         + that round's interest + joker income of the round (rental: $3 SAVED per rental
--           joker) + the SHOP that follows the blind (worth more as the antes go by, when
--           the build lacks jokers or xMult, less when there is nothing to spend) + one round
--           of growth for the jokers that scale and the "when blind is selected" jokers
--           (Cartomancer, Madness...), minus what a skip preserves (food jokers, Throwback);
--   value = what the tag gives in THIS situation: Investment $25 (best early), Coupon (best on
--           the first shops), a free Polychrome / Holographic / Negative joker, Economy and
--           Speed / Handy / Garbage by the amount they show, an Orbital Tag only on the main
--           hand, the Boss Tag only against a boss that counters the build...
-- and only when the blind that follows can be beaten without that shop: the Big Blind after
-- a skipped Small Blind; the BOSS, with no shop before it, after a skipped Big Blind (so Big
-- Blind skips stay rare). Shop tags pay only after that blind.
-- Before patch 1.0.1f (May 2024) tag jokers were NOT free and Investment gave $15: most
-- "never skip" advice predates it.
-- Pure functions of the state and of the outlook numbers passed in ctx.

local BSC = BSCopilot
local U = BSC.require('core/util')
local E = BSC.require('engine/economy')
local DB = BSC.require('model/jokers_db')
local PL = BSC.require('engine/plan')

local SK = {}

-- Vanilla tags (effects as written on the tags; min = first ante where the tag can appear).
--   kind: joker (a free joker takes a slot of the next shop), edition (the next base-edition
--   joker created in a shop, rerolls included, is free and gets this edition), pack (a free
--   pack opened at once), money... ; base: $ value in an ordinary early situation, adjusted
--   by SK.tag_value. Tiers of top players (synthesis): S Investment (antes 1-3), Coupon (first
--   shops); A Polychrome, Holographic (early), Negative, Economy (with money), Orbital (main
--   hand), Boss (against a counter); B Foil, Uncommon, Rare, Buffoon, Top-up, Handy;
--   C Charm, Ethereal, Meteor, Garbage, Speed (first skips); never Standard, Voucher, Juggle,
--   D6, Double without a plan.
SK.TAGS = {
    tag_uncommon = { kind = 'joker', rarity = 2, base = 6.5 },
    tag_rare = { kind = 'joker', rarity = 3, base = 10 },
    tag_negative = { kind = 'edition', edition = 'e_negative', min = 2 },
    tag_foil = { kind = 'edition', edition = 'e_foil' },
    tag_holo = { kind = 'edition', edition = 'e_holo' },
    tag_polychrome = { kind = 'edition', edition = 'e_polychrome' },
    tag_investment = { kind = 'investment', dollars = 25 },
    tag_voucher = { kind = 'voucher', base = 2 },
    tag_boss = { kind = 'boss' },
    tag_standard = { kind = 'pack', pack = 'Standard', base = 2, min = 2 },
    tag_charm = { kind = 'pack', pack = 'Arcana', base = 6 },
    tag_meteor = { kind = 'pack', pack = 'Celestial', base = 4, min = 2 },
    tag_buffoon = { kind = 'pack', pack = 'Buffoon', base = 9, min = 2, jokers = 2 },
    tag_handy = { kind = 'handy', min = 2 },
    tag_garbage = { kind = 'garbage', min = 2 },
    tag_ethereal = { kind = 'pack', pack = 'Spectral', base = 4, min = 2 },
    tag_coupon = { kind = 'coupon' },
    tag_double = { kind = 'double' },
    tag_juggle = { kind = 'juggle', base = 1 },
    tag_d_six = { kind = 'd6' },
    tag_top_up = { kind = 'topup', min = 2 },
    tag_skip = { kind = 'speed' },
    tag_orbital = { kind = 'orbital', min = 2 },
    tag_economy = { kind = 'economy' },
}

-- English names (the game's own localized name is used when the state has it)
SK.NAMES = {
    tag_uncommon = 'Uncommon Tag', tag_rare = 'Rare Tag', tag_negative = 'Negative Tag', tag_foil = 'Foil Tag',
    tag_holo = 'Holographic Tag', tag_polychrome = 'Polychrome Tag', tag_investment = 'Investment Tag',
    tag_voucher = 'Voucher Tag', tag_boss = 'Boss Tag', tag_standard = 'Standard Tag', tag_charm = 'Charm Tag',
    tag_meteor = 'Meteor Tag', tag_buffoon = 'Buffoon Tag', tag_handy = 'Handy Tag', tag_garbage = 'Garbage Tag',
    tag_ethereal = 'Ethereal Tag', tag_coupon = 'Coupon Tag', tag_double = 'Double Tag', tag_juggle = 'Juggle Tag',
    tag_d_six = 'D6 Tag', tag_top_up = 'Top-up Tag', tag_skip = 'Speed Tag', tag_orbital = 'Orbital Tag',
    tag_economy = 'Economy Tag',
}

function SK.tag_name(state, slot, tag)
    local n = state and state.blind_tag_names and state.blind_tag_names[slot]
    if type(n) == 'string' and n ~= '' then return n end
    return SK.NAMES[tag] or tostring(tag or '?')
end

-- Defaults (overridable from config.lua, section advice: skip_*)
SK.DEFAULTS = {
    skip_margin = 1,            -- the tag must be worth at least this many $ more than the skip costs
    skip_p_follow = 0.90,       -- skipping the Small Blind: Big Blind beaten with the current deck
    skip_p_boss = 0.90,         -- skipping the Big Blind: boss beaten with the current deck (no shop before it)
    skip_shop = { 4, 6, 10, 14 }, -- value of a shop visit: ante 1, ante 2, antes 3-6, 7-8 (top players' estimates)
}

local function setting(cfg, k)
    local a = cfg and cfg.advice
    local v = SK.DEFAULTS[k]
    if a and a[k] ~= nil then v = a[k] end
    -- adjustments learned from past runs (learning/adapt.lua)
    local d = (cfg and cfg.adapt_deltas) or (BSC.learning_runtime and BSC.learning_runtime.adapt_deltas and BSC.learning_runtime.adapt_deltas())
    if d and type(v) == 'number' then v = BSC.require('learning/adapt').apply(k, v, d) end
    return v
end

local function free_slots(state)
    local n = 0
    for _, j in ipairs(state.jokers or {}) do if j.edition ~= 'e_negative' then n = n + 1 end end
    return math.max(0, (state.joker_slots or 5) - n)
end

-- A joker brought by a tag needs a free slot; with full slots one must be sold first.
local function slot_factor(state, n)
    local free = free_slots(state)
    if free >= (n or 1) then return 1 end
    if free >= 1 then return 0.75 end
    return 0.45
end

-- $ beyond the interest cap no longer earn anything: extra money is worth a little less there.
local function money_factor(state)
    local econ = state.econ or {}
    local d = econ.dollars or 0
    local cap = econ.interest_cap or 25
    if d >= cap + 20 then return 0.8 end
    return 1
end

local function owned(state, key)
    for _, j in ipairs(state.jokers or {}) do if j.key == key and not j.debuff then return j end end
end

-- Jokers whose effect depends on cards held in hand (+3 hand size helps them).
local HELD = { j_baron = true, j_mime = true, j_shoot_the_moon = true, j_raised_fist = true }
-- "When blind is selected" jokers: a skipped blind gives them nothing.
local ON_SELECT = { j_cartomancer = true, j_madness = true, j_riff_raff = true, j_burglar = true, j_marble = true,
    j_ceremonial = true }
-- Food jokers: a skipped blind is not a round, they last longer.
local DECAY = { j_popcorn = true, j_ice_cream = true, j_turtle_bean = true, j_ramen = true, j_selzer = true }

local function scoring_jokers(state)
    local n = 0
    for _, j in ipairs(state.jokers or {}) do
        local k = PL.joker_kind(DB.get(j.key, j.name))
        if k == 'xmult' or k == 'additive' or k == 'scaling' or k == 'retrigger' then n = n + 1 end
    end
    return n
end

-- A free joker from a tag: kept if it helps, else sold (it sells for half its full price);
-- from Black Stake it may carry a sticker (Eternal, Perishable, Rental), worth less.
local function sticker_factor(state)
    local stake = (state.run and state.run.stake) or 1
    if stake >= 8 then return 0.6 end
    if stake >= 4 then return 0.7 end
    return 1
end

-- Value of the tag in $ equivalents. Returns value, reason key (i18n), detail.
-- ctx: { plan, usage, orbital_hand, p_boss, p_boss_generic, boss (blind entry), slot,
--        other_tag_value (Double: value of the other tag of the ante) }
function SK.tag_value(tag, state, ctx)
    ctx = ctx or {}
    local t = SK.TAGS[tag]
    if not t then return 3, 'tag_unknown' end
    local econ = state.econ or {}
    local dollars = econ.dollars or 0
    local cap = econ.interest_cap or 25
    local ante = (state.run and state.run.ante) or 1
    local plan = ctx.plan or {}
    local gaps = plan.gaps or {}
    local mf = money_factor(state)
    local weak = scoring_jokers(state) <= 1
    local k = t.kind
    if k == 'joker' then
        -- B tier: best as the first jokers of the run (a Rare can also be a Blueprint with
        -- nothing to copy yet: high variance)
        local v = t.base * slot_factor(state) * sticker_factor(state)
        if weak then v = v * 1.2 elseif ante >= 4 then v = v * 0.8 end
        return v, 'tagv_joker'
    elseif k == 'edition' then
        -- the next base joker of a shop: random (mostly common), free, with the edition
        local joker = 4 * (t.edition == 'e_negative' and 1 or slot_factor(state)) * sticker_factor(state)
        local ed
        if t.edition == 'e_polychrome' then ed = (ante <= 4) and 8 or 5            -- x1.5: A tier, early
        elseif t.edition == 'e_holo' then ed = (ante <= 2) and 6 or ((ante <= 4) and 3 or 1) -- +10 Mult fades
        elseif t.edition == 'e_foil' then ed = (ante <= 2) and 3 or 1              -- +50 Chips: B tier
        else ed = 6 + ((free_slots(state) == 0) and 2 or 0) end                    -- Negative: a slot
        if weak and t.edition ~= 'e_negative' then joker = joker * 1.25 end
        return joker + ed, 'tagv_edition'
    elseif k == 'investment' then
        -- S tier in antes 1-3; later mostly when short of money
        local f = (ante <= 3) and 1 or ((dollars < cap) and 0.8 or 0.5)
        return t.dollars * f * mf, 'tagv_money'
    elseif k == 'economy' then
        return math.min(math.max(0, dollars), 40) * mf, 'tagv_economy'
    elseif k == 'handy' then
        return ((state.run and state.run.hands_played) or 0) * mf, 'tagv_handy'
    elseif k == 'garbage' then
        local u = state.run and state.run.unused_discards
        if not u then u = 2 * math.max(0, ((state.run and state.run.round) or 1) - 1) end
        return u * mf, 'tagv_garbage'
    elseif k == 'speed' then
        return 5 * (((state.run and state.run.skips) or 0) + 1) * mf, 'tagv_speed'
    elseif k == 'coupon' then
        -- the first shop items free: best when money is short (S tier on the first shops)
        local v = (ante <= 2) and 12 or ((ante <= 4) and 9 or 6)
        if dollars >= cap then v = v - 3 end
        return v, 'tagv_coupon'
    elseif k == 'pack' then
        local v = t.base
        if t.jokers then v = v * slot_factor(state, t.jokers) * sticker_factor(state); if weak then v = v * 1.2 end end
        if t.pack == 'Celestial' and (owned(state, 'j_constellation') or (state.vouchers and state.vouchers.v_telescope)) then v = v + 3 end
        if t.pack == 'Standard' and owned(state, 'j_hologram') then v = v + 4 end
        return v, 'tagv_pack'
    elseif k == 'orbital' then
        -- only on the main hand (more before The Arm / The Flint)
        local hand = ctx.orbital_hand
        if not hand then return 3, 'tagv_orbital_unknown' end
        if hand == plan.main_hand then
            local v = 9 + ((ante >= 5) and 3 or 0)
            local bk = ctx.boss and ctx.boss.key
            if bk == 'bl_arm' or bk == 'bl_flint' then v = v + 3 end
            return v, 'tagv_orbital_main', hand
        end
        local usage = ctx.usage and ctx.usage[hand] or 0
        if usage >= 0.25 then return 4, 'tagv_orbital_used', hand end
        return 0, 'tagv_orbital_other', hand
    elseif k == 'boss' then
        -- only against a boss that counters the build: compared with an ordinary boss of the
        -- same size
        local pb, pg = ctx.p_boss, ctx.p_boss_generic
        if not pb or not pg then return 1, 'tagv_boss' end
        return U.clamp(pg - pb, 0, 1) * 60, 'tagv_boss'
    elseif k == 'd6' then
        return (dollars >= cap + 15) and 5 or 1, 'tagv_d6'
    elseif k == 'juggle' then
        -- worth something only right before a boss that shrinks the hand (Big Blind skip)
        local v = t.base
        local bk = ctx.boss and ctx.boss.key
        if ctx.slot == 'Big' and (bk == 'bl_manacle' or bk == 'bl_psychic') then v = v + 4 end
        if ctx.slot == 'Big' then for key, on in pairs(HELD) do if on and owned(state, key) then v = v + 2 end end end
        return v, 'tagv_juggle'
    elseif k == 'topup' then
        -- up to 2 commons without stickers: only with empty slots and a weak board
        local v = 2.5 * math.min(2, free_slots(state))
        if weak then v = v * 1.5 end
        return v, 'tagv_topup'
    elseif k == 'double' then
        -- copies the next tag: worth it only when the other tag of the ante is strong
        local o = ctx.other_tag_value or 0
        return (o >= 12) and 0.6 * o or 1, 'tagv_double'
    elseif k == 'voucher' then
        return t.base, 'tagv_voucher'
    end
    return t.base or 3, 'tag_unknown'
end

-- What the skip costs, in $. ctx: { current = blind, median = typical hand score, plan,
-- p_boss, boss }. Returns total, parts.
function SK.cost(state, ctx, cfg)
    ctx = ctx or {}
    local econ = state.econ or {}
    local dollars = econ.dollars or 0
    local ante = (state.run and state.run.ante) or 1
    local stake = (state.run and state.run.stake) or 1
    local cur = ctx.current or {}
    local parts = {}
    parts.reward = cur.reward or 0
    -- hands left unused at the end of the blind ($1 each): a typical round, with discards,
    -- scores about 1.5 typical hands per hand played (the typical hand is measured without
    -- discards, docs/MATHS.md)
    local h = (state.round and state.round.round_hands) or 4
    local per = math.max(1, 1.5 * (ctx.median or 0))
    local needed = U.clamp(math.ceil((cur.chips or 0) / per), 1, h)
    parts.hands = (h - needed) * (econ.money_per_hand or 1)
    parts.interest = E.interest(dollars, econ)
    -- joker money of the round (a rental joker costs $3 per round: SAVED by a skip)
    parts.jokers = (E.joker_income(state))
    -- the shop that follows the blind: top players' estimates grow with the antes
    local shop = setting(cfg, 'skip_shop') or SK.DEFAULTS.skip_shop
    local s = (ante <= 1) and shop[1] or ((ante <= 2) and shop[2] or ((ante <= 6) and shop[3] or shop[4]))
    local plan = ctx.plan or {}
    local gaps = plan.gaps or {}
    local money_there = dollars + parts.reward + parts.hands + parts.interest + math.max(0, parts.jokers)
    if money_there < 5 then s = s * 0.6 end                         -- almost nothing to buy with
    if gaps.power or gaps.xmult or gaps.scoring then s = s * 1.25 end -- the build needs that shop
    if free_slots(state) == 0 and not (gaps.power or gaps.xmult) then s = s * 0.8 end
    if cur.slot == 'Big' then s = s * 1.3 end                       -- the shop before the boss
    if ctx.p_boss and ctx.p_boss < 0.7 then s = s * 1.3 end         -- fewer shops before a hard boss
    if stake >= 6 then s = s * 1.2 end                              -- Purple Stake +: blinds grow faster
    parts.shop = s
    -- one round of growth lost by the jokers that scale; "when blind is selected" jokers get
    -- nothing; food jokers last one round longer
    local grow = 0
    for _, j in ipairs(state.jokers or {}) do
        if not j.debuff then
            if PL.joker_kind(DB.get(j.key, j.name)) == 'scaling' then grow = grow + ((ante <= 2) and 2 or 3) end
            if ON_SELECT[j.key] then grow = grow + 2 end
            if DECAY[j.key] then grow = grow - 1 end
        end
    end
    parts.growth = grow
    -- Throwback: x0.25 Mult for every blind skipped (the skip itself pays)
    parts.throwback = owned(state, 'j_throwback') and -6 or 0
    -- The Pillar: cards played in the skipped blind would be debuffed against the boss
    parts.pillar = (ctx.boss and ctx.boss.key == 'bl_pillar') and -3 or 0
    local total = 0
    for _, v in pairs(parts) do total = total + v end
    return total, parts
end

-- Full evaluation. ctx: { current, following, p_following, p_boss, p_boss_generic, median,
-- usage, plan, orbital_hand }.
function SK.evaluate(state, ctx, cfg)
    ctx = ctx or {}
    local cur = ctx.current
    local res = { method = 'heuristic' }
    if not cur or cur.boss then return nil end
    local tag = state.blind_tags and state.blind_tags[cur.slot]
    res.tag = tag
    if not tag then res.recommended = false; res.reason = 'no_tag'; return res end
    local ante = (state.run and state.run.ante) or 1
    ctx.slot = cur.slot
    -- Double Tag: worth the other tag of the ante when that one is strong
    local other = (cur.slot == 'Small') and state.blind_tags.Big or nil
    if tag == 'tag_double' and other and other ~= 'tag_double' then
        ctx.other_tag_value = (SK.tag_value(other, state, ctx))
    end
    local value, vwhy, vdetail = SK.tag_value(tag, state, ctx)
    -- Double Tags already held copy this tag (Anaglyph Deck stacks them)
    local doubles = 0
    for _, t in ipairs(state.tags_held or {}) do if t == 'tag_double' then doubles = doubles + 1 end end
    if doubles > 0 and tag ~= 'tag_double' then
        value = value * (1 + doubles)
        res.doubles = doubles
    end
    local cost, parts = SK.cost(state, ctx, cfg)
    res.tag_value, res.value_why, res.value_detail = value, vwhy, vdetail
    res.lost, res.parts = cost, parts
    res.shop_value = parts.shop
    res.margin = value - cost
    -- the blind that follows must be beaten without the skipped round's shop
    local p, need
    if cur.slot == 'Big' then p, need = ctx.p_boss, setting(cfg, 'skip_p_boss')
    else p, need = ctx.p_following, setting(cfg, 'skip_p_follow') end
    res.p_following = p
    res.p_needed = need
    res.following_is_boss = cur.slot == 'Big'
    local safe = (p or 0) >= need
    res.recommended = safe and res.margin >= setting(cfg, 'skip_margin')
    if not safe then res.reason = 'not_safe'
    elseif res.margin < setting(cfg, 'skip_margin') then res.reason = 'not_worth'
    else res.reason = 'worth' end
    -- high stakes (Green Stake and up): the best players almost never skip, the round's shop is
    -- worth more than a tag when the blinds grow x2.5 to x3 per ante; the standard exception is
    -- the Investment Tag in the first antes (research 1.0.10). Simulated black-stake runs skipped
    -- 17 blinds in 20 runs before this rule.
    local PL = BSC.require('engine/plan')
    if res.recommended and PL.high_stakes(state) and not (tag == 'tag_investment' and ante <= 2) then
        res.recommended = false
        res.reason = 'high_stake'
    end
    res.ante = ante
    return res
end

return SK
