-- Balatro Strategic Copilot - engine/hand_advisor.lua  (HandAdvisor)
-- Analyses the current hand: every legal play (exact score distributions), targeted
-- discards (exact completion probabilities on the known deck composition), and the
-- probability of beating the blind for each candidate action, estimated by simulating the
-- rest of the round with an EXPLICIT policy (documented in docs/MATHS.md):
--   1. if a play reaches the remaining score -> play it;
--   2. else if hands remain and the best play keeps pace (best * hands_left >= remaining)
--      -> play the best play;
--   3. else if discards remain -> discard toward the most promising target;
--   4. else play the best play.
-- Draws use the known remaining deck in a random order (the real order is never read).

local BSC = BSCopilot
local U = BSC.require('core/util')
local R = BSC.require('core/rng')
local C = BSC.require('model/cards')
local H = BSC.require('model/hands')
local PE = BSC.require('engine/poker_eval')
local Score = BSC.require('engine/score')
local PR = BSC.require('engine/probability')

local HA = {}

local function noop() end

-- rough ordering of cards when several could fill the same role
local function card_value(c)
    local v = (c.nominal or 0) + (c.bonus or 0) + (c.perma_bonus or 0)
    v = v + 6 * ((c.mult or 0) + (c.perma_mult or 0))
    if (c.x_mult or 1) > 1 then v = v + 40 * (c.x_mult - 1) end
    if c.edition == 'e_polychrome' then v = v + 30 elseif c.edition == 'e_holo' then v = v + 25 elseif c.edition == 'e_foil' then v = v + 15 end
    if c.seal == 'Red' then v = v + 15 elseif c.seal == 'Gold' then v = v + 5 end
    if c.debuff then v = v - 50 end
    return v
end
HA.card_value = card_value

local function by_value_desc(a, b)
    local va, vb = card_value(a), card_value(b)
    if va ~= vb then return va > vb end
    return tostring(a.uid) < tostring(b.uid)
end

local function key_of(cards)
    local ids = {}
    for i, c in ipairs(cards) do ids[i] = tostring(c.uid) end
    table.sort(ids)
    return table.concat(ids, ',')
end
HA.key_of = key_of

local function minus(all, removed)
    local set = {}
    for _, c in ipairs(removed) do set[c] = true end
    local out = {}
    for _, c in ipairs(all) do if not set[c] then out[#out + 1] = c end end
    return out
end
HA.minus = minus

local function in_hand_order(hand, subset)
    local set = {}
    for _, c in ipairs(subset) do set[c] = true end
    local out = {}
    for _, c in ipairs(hand) do if set[c] then out[#out + 1] = c end end
    return out
end

-- Structural play candidates (fast, used inside simulations) -------------------------------
function HA.structural_candidates(hand, rules, opts)
    opts = opts or {}
    local out, seen = {}, {}
    local function add(cards)
        if #cards == 0 or #cards > 5 then return end
        local ordered = in_hand_order(hand, cards)
        local k = key_of(ordered)
        if not seen[k] then seen[k] = true; out[#out + 1] = ordered end
    end
    local visible = {}
    for _, c in ipairs(hand) do if not c.face_down then visible[#visible + 1] = c end end

    -- rank groups
    local groups = {}
    for _, c in ipairs(visible) do
        if C.has_rank(c) then
            groups[c.id] = groups[c.id] or {}
            table.insert(groups[c.id], c)
        end
    end
    local glist = {}
    for id, g in pairs(groups) do table.sort(g, by_value_desc); glist[#glist + 1] = { id = id, cards = g } end
    table.sort(glist, function(a, b)
        if #a.cards ~= #b.cards then return #a.cards > #b.cards end
        return a.id > b.id
    end)
    for _, g in ipairs(glist) do
        if #g.cards >= 2 then
            local t = {}
            for i = 1, math.min(5, #g.cards) do t[i] = g.cards[i] end
            add(t)
        end
    end
    -- two pair / full house
    local multi = {}
    for _, g in ipairs(glist) do if #g.cards >= 2 then multi[#multi + 1] = g end end
    for i = 1, math.min(#multi, 3) do
        for j = i + 1, math.min(#multi, 4) do
            local a, b = multi[i].cards, multi[j].cards
            local t = { a[1], a[2], b[1], b[2] }
            if #a >= 3 then t = { a[1], a[2], a[3], b[1], b[2] }
            elseif #b >= 3 then t = { b[1], b[2], b[3], a[1], a[2] } end
            add(t)
        end
    end
    -- flushes
    local need = rules and rules.four_fingers and 4 or 5
    for _, suit in ipairs(C.SUITS) do
        local t = {}
        for _, c in ipairs(visible) do if C.is_suit(c, suit, rules, nil, true) then t[#t + 1] = c end end
        if #t >= need then
            table.sort(t, by_value_desc)
            local pick = {}
            for i = 1, math.min(5, #t) do pick[i] = t[i] end
            add(pick)
        end
    end
    -- straights (one card per rank among distinct ranks present)
    local reps = {}
    for _, g in ipairs(glist) do reps[#reps + 1] = g.cards[1] end
    if #reps >= need then
        local combos = U.subsets(#reps, need, math.min(5, #reps))
        for _, idx in ipairs(combos) do
            local t = {}
            for i, k in ipairs(idx) do t[i] = reps[k] end
            if next(PE.straight(t, rules)) then add(t) end
        end
    end
    -- high card(s)
    local sorted = {}
    for i, c in ipairs(visible) do sorted[i] = c end
    table.sort(sorted, function(a, b) return C.nominal_key(a) > C.nominal_key(b) end)
    if sorted[1] then add({ sorted[1] }) end
    -- filled variants (play up to 5 cards to cycle the hand; scoring decides if it hurts)
    local base_count = #out
    local low = {}
    for i, c in ipairs(visible) do low[i] = c end
    table.sort(low, function(a, b) return card_value(a) < card_value(b) end)
    for i = 1, base_count do
        local cand = out[i]
        if #cand < 5 then
            local set = {}
            for _, c in ipairs(cand) do set[c] = true end
            local t = {}
            for _, c in ipairs(cand) do t[#t + 1] = c end
            for _, c in ipairs(low) do
                if #t >= 5 then break end
                if not set[c] then t[#t + 1] = c end
            end
            add(t)
        end
    end
    -- constraints
    if opts.forced or opts.min_cards then
        local filtered = {}
        for _, cand in ipairs(out) do
            local okf = true
            if opts.forced then
                okf = false
                for _, c in ipairs(cand) do if c == opts.forced then okf = true end end
            end
            if okf and (not opts.min_cards or #cand >= opts.min_cards) then filtered[#filtered + 1] = cand end
        end
        out = filtered
    end
    return out
end

-- Fast best play (simulation inner loop)
function HA.best_play_fast(P, hand, rng, opts)
    local cands = HA.structural_candidates(hand, P.rules, opts)
    local best, best_score, best_hand
    for _, cand in ipairs(cands) do
        local held = minus(hand, cand)
        local s, hname = Score.quick(P, cand, held, rng, 1)
        if not best or s > best_score or (s == best_score and #cand > #best) then
            best, best_score, best_hand = cand, s, hname
        end
    end
    return best, best_score or 0, best_hand
end

-- Discard targets ---------------------------------------------------------------------------

local WINDOWS = {}
do
    -- A-low wheel then 2-6 ... 10-A
    WINDOWS[#WINDOWS + 1] = { 14, 2, 3, 4, 5 }
    for start = 2, 10 do WINDOWS[#WINDOWS + 1] = { start, start + 1, start + 2, start + 3, start + 4 } end
end

-- Build discard candidates. Each: { discard = {cards}, keep = {cards}, target = {name, detail},
--   p_complete = exact probability of completing the target with the next draw }
function HA.discard_targets(state, hand, deck, opts)
    opts = opts or {}
    local rules = opts.rules or {}
    local limit = opts.discard_limit or 5
    local hand_size = (state.round and state.round.hand_size) or 8
    local N = #deck
    local out, seen = {}, {}
    local visible = {}
    for _, c in ipairs(hand) do if not c.face_down then visible[#visible + 1] = c end end

    local function finish(keep, target, p)
        local keep_set = {}
        for _, c in ipairs(keep) do keep_set[c] = true end
        if opts.forced then keep_set[opts.forced] = true end
        local others = {}
        for _, c in ipairs(hand) do if not keep_set[c] then others[#others + 1] = c end end
        if #others == 0 then return end
        table.sort(others, function(a, b) return card_value(a) < card_value(b) end)
        local discard = {}
        for i = 1, math.min(limit, #others) do discard[i] = others[i] end
        discard = in_hand_order(hand, discard)
        local k = key_of(discard)
        if seen[k] then
            -- keep the best target description for identical discards
            if p and seen[k].p_complete and p > seen[k].p_complete then seen[k].target = target; seen[k].p_complete = p end
            return
        end
        local entry = { discard = discard, keep = in_hand_order(hand, minus(hand, discard)), target = target, p_complete = p }
        seen[k] = entry
        out[#out + 1] = entry
    end

    local function draws_after(nd)
        local n = math.min(nd, math.max(0, hand_size - (#hand - nd)))
        if opts.serpent then n = 3 end
        return math.min(n, N)
    end

    -- deck counts
    local suit_count = { Spades = 0, Hearts = 0, Clubs = 0, Diamonds = 0 }
    local rank_count = {}
    for _, c in ipairs(deck) do
        for _, s in ipairs(C.SUITS) do if C.is_suit(c, s, rules, nil, true) then suit_count[s] = suit_count[s] + 1 end end
        if C.has_rank(c) then rank_count[c.id] = (rank_count[c.id] or 0) + 1 end
    end

    -- flush targets
    local need = rules.four_fingers and 4 or 5
    for _, suit in ipairs(C.SUITS) do
        local keep = {}
        for _, c in ipairs(visible) do if C.is_suit(c, suit, rules, nil, true) then keep[#keep + 1] = c end end
        if #keep >= 2 and #keep < need then
            table.sort(keep, by_value_desc)
            local nd = math.min(limit, #hand - #keep)
            local n = draws_after(nd)
            local p = PR.hypergeom_at_least(N, suit_count[suit], n, need - #keep)
            finish(keep, { name = 'Flush', suit = suit, have = #keep, need = need }, p)
        end
    end
    -- straight targets
    local present = {}
    for _, c in ipairs(visible) do if C.has_rank(c) then present[c.id] = present[c.id] or c end end
    for _, w in ipairs(WINDOWS) do
        local keep, missing = {}, {}
        local slots = rules.four_fingers and 4 or 5
        for i = 1, 5 do
            local id = w[i]
            if present[id] then keep[#keep + 1] = present[id] else missing[#missing + 1] = rank_count[id] or 0 end
        end
        if #keep >= slots - 2 and #keep < slots then
            local nd = math.min(limit, #hand - #keep)
            local n = draws_after(nd)
            -- need (slots - have) distinct missing ranks among the 5 - have missing ones
            local p = PR.groups_hit_at_least(N, missing, n, slots - #keep)
            finish(keep, { name = 'Straight', low = w[1], have = #keep, need = slots }, p)
        end
    end
    -- rank groups: pair -> trips etc.
    local groups = {}
    for _, c in ipairs(visible) do
        if C.has_rank(c) then groups[c.id] = groups[c.id] or {}; table.insert(groups[c.id], c) end
    end
    local glist = {}
    for id, g in pairs(groups) do glist[#glist + 1] = { id = id, cards = g } end
    table.sort(glist, function(a, b)
        if #a.cards ~= #b.cards then return #a.cards > #b.cards end
        return a.id > b.id
    end)
    for i, g in ipairs(glist) do
        if i > 4 then break end
        local nd = math.min(limit, #hand - #g.cards)
        local n = draws_after(nd)
        local p = PR.any_hit(N, rank_count[g.id] or 0, n)
        local names = { 'Pair', 'Three of a Kind', 'Four of a Kind', 'Five of a Kind' }
        finish(g.cards, { name = names[math.min(#g.cards, 4)], rank = g.id, have = #g.cards }, p)
    end
    -- two pairs kept -> full house
    local pairs_ = {}
    for _, g in ipairs(glist) do if #g.cards >= 2 then pairs_[#pairs_ + 1] = g end end
    if #pairs_ >= 2 then
        local a, b = pairs_[1], pairs_[2]
        local keep = {}
        for _, c in ipairs(a.cards) do keep[#keep + 1] = c end
        for _, c in ipairs(b.cards) do keep[#keep + 1] = c end
        local nd = math.min(limit, #hand - #keep)
        local n = draws_after(nd)
        local p = PR.any_hit(N, (rank_count[a.id] or 0) + (rank_count[b.id] or 0), n)
        finish(keep, { name = 'Full House', have = 4 }, p)
    end
    -- keep the best current play's scoring cards (generic "improve" discard)
    if opts.best_play then
        finish(opts.best_play, { name = 'Keep', detail = 'best' }, nil)
    end
    return out
end

-- Evaluate a target's potential: complete it with representative deck cards and score it.
local function target_potential(P, entry, deck, rng, rules)
    local t = entry.target
    local keep = entry.keep
    local filler = {}
    if t.name == 'Flush' then
        for _, c in ipairs(deck) do if C.is_suit(c, t.suit, rules, nil, true) then filler[#filler + 1] = c end end
        table.sort(filler, by_value_desc)
        local need = t.need - t.have
        local add = {}
        for i = 1, math.min(need, #filler) do add[i] = filler[i] end
        filler = add
    elseif t.name == 'Straight' then
        local have = {}
        for _, c in ipairs(keep) do if C.has_rank(c) then have[c.id] = true end end
        local ids = {}
        local low = t.low
        for i = 0, 4 do
            local id = (low == 14) and ({ 14, 2, 3, 4, 5 })[i + 1] or (low + i)
            if not have[id] then ids[id] = true end
        end
        local add, used = {}, {}
        for _, c in ipairs(deck) do
            if C.has_rank(c) and ids[c.id] and not used[c.id] then add[#add + 1] = c; used[c.id] = true end
        end
        filler = add
    elseif t.rank then
        for _, c in ipairs(deck) do
            if C.has_rank(c) and c.id == t.rank then filler[#filler + 1] = c; break end
        end
    else
        return nil
    end
    local played = {}
    local base_keep = {}
    for _, c in ipairs(keep) do base_keep[#base_keep + 1] = c end
    -- play the target cards only (up to 5)
    local pool = {}
    if t.name == 'Flush' then
        for _, c in ipairs(keep) do if C.is_suit(c, t.suit, rules, nil, true) then pool[#pool + 1] = c end end
    elseif t.name == 'Straight' then
        pool = keep
    else
        for _, c in ipairs(keep) do if C.has_rank(c) and c.id == t.rank then pool[#pool + 1] = c end end
    end
    for _, c in ipairs(pool) do if #played < 5 then played[#played + 1] = c end end
    for _, c in ipairs(filler) do if #played < 5 then played[#played + 1] = c end end
    if #played == 0 then return nil end
    local s = Score.quick(P, played, minus(base_keep, played), rng, 1)
    return s
end

-- Simulation of the rest of the round -----------------------------------------------------

local function draw(hand, deck, pos, n)
    for _ = 1, n do
        local c = deck[pos]
        if not c then break end
        hand[#hand + 1] = c
        pos = pos + 1
    end
    return pos
end

-- Policy decision for a simulated state. Returns {type='play'|'discard', cards}.
function HA.policy(P, hand, h, d, remaining, deck_rest, rng, ctx)
    local best, best_score = HA.best_play_fast(P, hand, rng, ctx.play_opts)
    if not best then return { type = 'discard', cards = { hand[1] } } end
    if best_score >= remaining then return { type = 'play', cards = best } end
    local on_track = best_score * h >= remaining
    if d > 0 and (not on_track or h == 1) then
        local targets = HA.discard_targets(ctx.state, hand, deck_rest, { rules = P.rules, forced = ctx.forced, serpent = ctx.serpent, best_play = best })
        local best_t, best_v
        for _, t in ipairs(targets) do
            local pot = t.p_complete and target_potential(P, t, deck_rest, rng, P.rules)
            local v
            if pot then v = t.p_complete * pot + (1 - t.p_complete) * best_score * 0.9
            else v = best_score * 0.95 end
            if not best_v or v > best_v then best_t, best_v = t, v end
        end
        if best_t and best_v > best_score then return { type = 'discard', cards = best_t.discard } end
    end
    return { type = 'play', cards = best }
end

-- One rollout from a root action. Returns cleared (bool), hands_used.
function HA.rollout(P0, root, hand0, deck_cards, h, d, remaining, rng, ctx)
    -- random order of the unknown draw pile
    local deck = {}
    for i, c in ipairs(deck_cards) do deck[i] = c end
    rng:shuffle(deck)
    local pos = 1
    local hand = {}
    for i, c in ipairs(hand0) do hand[i] = c end
    local P = P0
    local action = root
    local hands_used = 0
    local dollars = P0.dollars
    local hands_played = P0.hands_played_total
    for _ = 1, 40 do
        if action.type == 'play' then
            local held = minus(hand, action.cards)
            local Pstep = Score.derive(P, { hands_left = h, discards_left = d, deck_count = #deck - pos + 1,
                dollars = dollars, hands_played = hands_played })
            local s, _, _, r = Score.quick(Pstep, action.cards, held, rng, 1)
            remaining = remaining - s
            h = h - 1
            hands_used = hands_used + 1
            hands_played = hands_played + 1
            if r then
                dollars = dollars + (r.dollars or 0)
                if r.jokers_after then P = Score.derive(P, { jokers_after = r.jokers_after }) end
            end
            if remaining <= 0 then return true, hands_used end
            if h <= 0 then return false, hands_used end
            hand = held
            local n = ctx.serpent and 3 or math.max(0, ctx.hand_size - #hand)
            pos = draw(hand, deck, pos, n)
        else
            hand = minus(hand, action.cards)
            d = d - 1
            local n = ctx.serpent and 3 or math.max(0, ctx.hand_size - #hand)
            pos = draw(hand, deck, pos, n)
        end
        if #hand == 0 then return false, hands_used end
        local rest = {}
        for i = pos, #deck do rest[#rest + 1] = deck[i] end
        local Pstep = Score.derive(P, { hands_left = h, discards_left = d, deck_count = #rest, dollars = dollars, hands_played = hands_played })
        action = HA.policy(Pstep, hand, h, d, remaining, rest, rng, ctx)
    end
    return false, hands_used
end

-- Full analysis --------------------------------------------------------------------------
-- opts: { rollouts = 64, max_play_candidates = 4, max_discard_candidates = 5, seed }
-- Face-down cards in hand --------------------------------------------------------------------
-- The House (first hand face down), The Mark (face cards), The Wheel (1 in 7), The Fish...
-- The player sees neither the rank nor the suit of these cards, but knows which cards they can
-- be: the deck view shows the draw pile, so hidden cards come from
--     full deck - draw pile - visible cards in hand
-- (this pool also holds the discard pile: nothing the player cannot know is used, and the
-- identity of a given hidden card is never read). Hidden positions are therefore
-- interchangeable: a candidate action is a set of VISIBLE cards plus a NUMBER of hidden cards,
-- evaluated by Monte Carlo over the identities of the hidden cards, with common random numbers
-- across candidates. In the simulated rest of the round, cards still hidden after the first
-- action STAY unknown (no rank, no suit): the policy cannot build on them and tends to
-- discard them, as the player would. Slightly pessimistic if they are later played blind
-- (documented in docs/MATHS.md).
function HA.hidden_pool(state, visible)
    local skip = {}
    for _, c in ipairs(state.deck or {}) do skip[tostring(c.uid)] = true end
    for _, c in ipairs(visible or {}) do skip[tostring(c.uid)] = true end
    local pool = {}
    for _, c in ipairs(state.full_deck or {}) do
        if not skip[tostring(c.uid)] then pool[#pool + 1] = c end
    end
    return pool
end

-- one possible identity for every hidden card (copies keep the hidden card's uid/position)
local function assign_hidden(hidden, pool, rng)
    local ids = rng:sample(pool, #hidden)
    local map = {}
    for i, hc in ipairs(hidden) do
        local src = ids[i] or pool[((i - 1) % math.max(1, #pool)) + 1]
        local c = C.copy(src or hc)
        c.uid = hc.uid
        c.face_down = nil
        c.forced = hc.forced
        if hc.debuff then c.debuff = true end
        map[hc] = c
    end
    return map
end

local function concrete(cards, map)
    local out = {}
    for i, c in ipairs(cards) do out[i] = map[c] or c end
    return out
end

function HA.analyse_hidden(state, opts, task, P, hand, visible, hidden, forced)
    local check = (task and task.check) or noop
    local deck = state.deck or {}
    local round = state.round or {}
    local h, d = round.hands_left or 1, round.discards_left or 0
    local blind = state.blind or {}
    local remaining = math.max(0, (blind.chips_required or 0) - (blind.chips_scored or 0))
    local res = { remaining = remaining, hands_left = h, discards_left = d, plays = {}, discards = {}, notes = { 'hidden_cards' } }
    local pool = HA.hidden_pool(state, visible)
    if #pool < #hidden then
        -- inconsistent counts (cards created/destroyed by other mods): widen with the draw pile
        for _, c in ipairs(deck) do pool[#pool + 1] = c end
    end
    res.hidden = { count = #hidden, pool = #pool }
    local min_cards = (P.boss == 'bl_psychic') and 5 or nil
    local S = opts.hidden_samples or 24
    local maps = {}
    for i = 1, S do maps[i] = assign_hidden(hidden, pool, R.new('hidden:' .. i)) end

    -- candidates: visible cards + the first k hidden positions (positions are interchangeable)
    local cands = {}
    local function hidden_pick(k) local t = {} for i = 1, k do t[i] = hidden[i] end return t end
    local function add(kind, vis, k)
        local cards = {}
        for _, c in ipairs(vis) do cards[#cards + 1] = c end
        for _, c in ipairs(hidden_pick(k)) do cards[#cards + 1] = c end
        if #cards == 0 or #cards > 5 then return end
        if kind == 'play' and forced then
            local has = false
            for _, c in ipairs(cards) do if c == forced then has = true end end
            if not has then return end
        end
        if kind == 'play' and min_cards and #cards < min_cards and #hand >= min_cards then return end
        cands[#cands + 1] = { type = kind, cards = in_hand_order(hand, cards), hidden_n = k, vis_n = #vis }
    end
    -- visible-only plays: exact immediate value with hidden held cards unknown (no effect)
    local vis_plays = {}
    if #visible > 0 then
        for _, idx in ipairs(U.subsets(#visible, 1, math.min(5, #visible))) do
            check()
            local cards = {}
            for i, k in ipairs(idx) do cards[i] = visible[k] end
            local r = Score.evaluate_prepared(P, cards, minus(hand, cards), { max_branches = 16, samples = 48, seed = 'play' })
            vis_plays[#vis_plays + 1] = { cards = cards, mean = r.mean or 0 }
        end
        table.sort(vis_plays, function(a, b) return a.mean > b.mean end)
    end
    for i = 1, math.min(4, #vis_plays) do add('play', vis_plays[i].cards, 0) end
    for k = 1, math.min(5, #hidden) do add('play', {}, k) end
    for i = 1, math.min(3, #vis_plays) do
        for k = 1, math.min(#hidden, 5 - #vis_plays[i].cards) do add('play', vis_plays[i].cards, k) end
    end
    if d > 0 then
        for k = 1, math.min(5, #hidden) do add('discard', {}, k) end
        if #visible > 0 then
            local ok, targets = pcall(HA.discard_targets, state, visible, deck, { rules = P.rules, forced = forced,
                serpent = P.boss == 'bl_serpent' })
            if ok and targets then
                table.sort(targets, function(a, b) return (a.p_complete or 0) > (b.p_complete or 0) end)
                for i = 1, math.min(3, #targets) do
                    add('discard', targets[i].discard or {}, 0)
                    cands[#cands].target = targets[i].target
                    cands[#cands].p_complete = targets[i].p_complete
                end
            end
        end
    end
    if #cands == 0 then res.empty = true; return res end

    -- immediate value of plays, averaged over the possible identities of the hidden cards
    for _, c in ipairs(cands) do
        if c.type == 'play' then
            local sum_p, sum_m, names = 0, 0, {}
            for i = 1, S do
                check()
                local played = concrete(c.cards, maps[i])
                local held = concrete(minus(hand, c.cards), maps[i])
                local r = Score.evaluate_prepared(P, played, held, { max_branches = 16, samples = 48, seed = 'play' })
                sum_p = sum_p + ((remaining > 0) and r.p_at_least(remaining) or 1)
                sum_m = sum_m + (r.mean or 0)
                if r.hand then names[r.hand] = (names[r.hand] or 0) + 1 end
            end
            local best_name, best_n = nil, 0
            for n, k in pairs(names) do if k > best_n then best_name, best_n = n, k end end
            local entry = { cards = c.cards, uids = {}, hand = best_name, hand_share = best_n / S, mean = sum_m / S,
                p_win = sum_p / S, method = 'monte_carlo', exact = false, complete = true, n = #c.cards, hidden_n = c.hidden_n }
            for i, cc in ipairs(c.cards) do entry.uids[i] = cc.uid end
            c.ref = entry
            res.plays[#res.plays + 1] = entry
        else
            c.ref = { discard = c.cards, target = c.target, p_complete = c.p_complete, hidden_n = c.hidden_n }
            res.discards[#res.discards + 1] = c.ref
        end
    end
    table.sort(res.plays, function(a, b)
        if math.abs(a.p_win - b.p_win) > 1e-9 then return a.p_win > b.p_win end
        -- same chances: do not play hidden cards blind without need (a random card can change
        -- the hand type, which some bosses punish)
        if (a.hidden_n or 0) ~= (b.hidden_n or 0) then return (a.hidden_n or 0) < (b.hidden_n or 0) end
        if a.mean ~= b.mean then return a.mean > b.mean end
        return a.n > b.n
    end)
    res.best_play = res.plays[1]
    res.coverage = P.coverage

    local wins_now = res.best_play and res.best_play.p_win >= 1 - 1e-12
    if wins_now or (h <= 1 and d == 0) or not res.best_play and d == 0 then
        local p = res.best_play and res.best_play.p_win or 0
        res.round = { p_clear = p, method = 'monte_carlo', n = S, lo = p, hi = p }
        res.recommendation = { type = 'play', ref = res.best_play, cards = res.best_play and res.best_play.cards, p_clear = p, method = 'monte_carlo', n = S }
        return res
    end

    -- rest of the round, simulated for every candidate (same hidden identities per run)
    local ctx = { state = state, forced = forced, serpent = P.boss == 'bl_serpent',
        hand_size = round.hand_size or 8, play_opts = { forced = forced, min_cards = min_cards } }
    local n = opts.rollouts or 64
    local function run(c, from, to)
        for i = from, to do
            check()
            local rng = R.new((opts.seed or 'round') .. ':hidden:' .. i)
            local map = assign_hidden(hidden, pool, rng)
            -- only the hidden cards used by the first action get an identity (they are revealed)
            local acted = {}
            for _, cc in ipairs(c.cards) do if map[cc] then acted[cc] = map[cc] end end
            local hand_i = concrete(hand, acted)
            local ok, hands_used = HA.rollout(P, { type = c.type, cards = concrete(c.cards, acted) }, hand_i, deck, h, d, remaining, rng, ctx)
            c.runs = (c.runs or 0) + 1
            if ok then c.wins = (c.wins or 0) + 1; c.used = (c.used or 0) + (hands_used or 0) end
        end
        local p, lo, hi = PR.wilson(c.wins or 0, c.runs)
        c.p_clear, c.lo, c.hi, c.n = p, lo, hi, c.runs
        c.hands_used = (c.wins or 0) > 0 and c.used / c.wins or math.huge
        if c.ref then c.ref.p_clear = p; c.ref.p_lo = lo; c.ref.p_hi = hi; c.ref.sim_n = c.runs end
    end
    -- two stages: every candidate is screened, the most promising ones are refined
    local n1 = math.min(n, 16)
    for _, c in ipairs(cands) do run(c, 1, n1) end
    if n > n1 then
        table.sort(cands, function(a, b) return a.p_clear > b.p_clear end)
        for k = 1, math.min(#cands, opts.hidden_refine or 6) do run(cands[k], n1 + 1, n) end
    end
    table.sort(cands, function(a, b)
        if (a.n or 0) ~= (b.n or 0) then return (a.n or 0) > (b.n or 0) end -- refined ones first
        if math.abs(a.p_clear - b.p_clear) > 1e-9 then return a.p_clear > b.p_clear end
        if math.abs(a.hands_used - b.hands_used) > 0.05 then return a.hands_used < b.hands_used end
        if a.type ~= b.type then return a.type == 'play' end
        if (a.hidden_n or 0) ~= (b.hidden_n or 0) then return (a.hidden_n or 0) < (b.hidden_n or 0) end
        return #a.cards < #b.cards
    end)
    local best = cands[1]
    res.round = { p_clear = best.p_clear, method = 'monte_carlo', n = best.n, lo = best.lo, hi = best.hi }
    res.recommendation = { type = best.type, ref = best.ref, cards = best.cards, p_clear = best.p_clear,
        lo = best.lo, hi = best.hi, method = 'monte_carlo', n = best.n, hidden_n = best.hidden_n }
    res.candidates = cands
    return res
end

function HA.analyse(state, opts, task)
    opts = opts or {}
    local check = (task and task.check) or noop
    local t0 = U.now()
    local P = Score.prepare(state)
    local hand = state.hand_cards or {}
    local deck = state.deck or {}
    local round = state.round or {}
    local h, d = round.hands_left or 1, round.discards_left or 0
    local blind = state.blind or {}
    local remaining = math.max(0, (blind.chips_required or 0) - (blind.chips_scored or 0))
    local res = { remaining = remaining, hands_left = h, discards_left = d, plays = {}, discards = {}, notes = {} }

    local visible, forced = {}, nil
    for _, c in ipairs(hand) do
        if not c.face_down then visible[#visible + 1] = c end
        if c.forced then forced = c end
    end
    if #visible < #hand then
        local hidden = {}
        for _, c in ipairs(hand) do if c.face_down then hidden[#hidden + 1] = c end end
        local r = HA.analyse_hidden(state, opts, task, P, hand, visible, hidden, forced)
        r.total_ms = (U.now() - t0) * 1000
        return r
    end
    local min_cards = (P.boss == 'bl_psychic') and 5 or nil
    if #visible == 0 then res.empty = true; return res end

    -- 1. every legal play, exact distributions
    local subsets = U.subsets(#visible, 1, math.min(5, #visible))
    local seen = {}
    for _, idx in ipairs(subsets) do
        check()
        local cards = {}
        for i, k in ipairs(idx) do cards[i] = visible[k] end
        local legal = true
        if forced then
            legal = false
            for _, c in ipairs(cards) do if c == forced then legal = true end end
        end
        if min_cards and #cards < min_cards and #visible >= min_cards then legal = false end
        if legal then
            local held = minus(hand, cards)
            local r = Score.evaluate_prepared(P, cards, held, { max_branches = opts.max_branches or 48, samples = opts.samples or 160, seed = 'play' })
            local entry = { cards = cards, uids = {}, hand = r.hand, mean = r.mean, min = r.min, max = r.max,
                p_win = (remaining > 0) and r.p_at_least(remaining) or 1, method = r.method, exact = r.exact,
                complete = r.complete, dollars = r.dollars, debuffed_hand = r.debuffed_hand, n = #cards }
            for i, c in ipairs(cards) do entry.uids[i] = c.uid end
            res.plays[#res.plays + 1] = entry
        end
    end
    table.sort(res.plays, function(a, b)
        if math.abs(a.p_win - b.p_win) > 1e-9 then return a.p_win > b.p_win end
        if a.mean ~= b.mean then return a.mean > b.mean end
        return a.n > b.n
    end)
    res.best_play = res.plays[1]
    res.coverage = P.coverage
    res.enum_ms = (U.now() - t0) * 1000

    -- 2. discard candidates (exact completion probabilities)
    if d > 0 then
        res.discards = HA.discard_targets(state, hand, deck, { rules = P.rules, forced = forced,
            serpent = P.boss == 'bl_serpent', best_play = res.best_play and res.best_play.cards })
    end

    -- 3. round simulation for candidate actions
    local wins_now = res.best_play and res.best_play.p_win >= 1 - 1e-12
    local ctx = { state = state, forced = forced, serpent = P.boss == 'bl_serpent',
        hand_size = round.hand_size or 8, play_opts = { forced = forced, min_cards = min_cards } }
    local candidates = {}
    local by_mean = {}
    for i, p in ipairs(res.plays) do by_mean[i] = p end
    table.sort(by_mean, function(a, b) return a.mean > b.mean end)
    local added = {}
    local function add_play(p)
        if p and not added[p] then added[p] = true; candidates[#candidates + 1] = { type = 'play', cards = p.cards, ref = p } end
    end
    for i = 1, math.min(opts.max_play_candidates or 3, #res.plays) do add_play(res.plays[i]) end
    for i = 1, math.min(2, #by_mean) do add_play(by_mean[i]) end
    if d > 0 then
        local ds = {}
        for _, t in ipairs(res.discards) do ds[#ds + 1] = t end
        table.sort(ds, function(a, b) return (a.p_complete or 0) > (b.p_complete or 0) end)
        for i = 1, math.min(opts.max_discard_candidates or 5, #ds) do
            candidates[#candidates + 1] = { type = 'discard', cards = ds[i].discard, ref = ds[i] }
        end
    end

    if wins_now then
        res.round = { p_clear = 1, method = 'exact', n = 0, lo = 1, hi = 1 }
        res.recommendation = { type = 'play', ref = res.best_play, p_clear = 1, method = 'exact' }
    elseif h <= 1 and (d == 0) then
        local p = res.best_play and res.best_play.p_win or 0
        local m = res.best_play and ((res.best_play.method == 'monte_carlo') and 'monte_carlo' or 'exact') or 'exact'
        res.round = { p_clear = p, method = m, n = 0, lo = p, hi = p }
        res.recommendation = { type = 'play', ref = res.best_play, p_clear = p, method = m }
    else
        local n = opts.rollouts or 64
        local seed = opts.seed or 'round'
        for _, cand in ipairs(candidates) do
            local wins, used = 0, 0
            for i = 1, n do
                check()
                local rng = R.new(seed .. ':' .. i) -- common random numbers across candidates
                local ok, hands_used = HA.rollout(P, cand, hand, deck, h, d, remaining, rng, ctx)
                if ok then wins = wins + 1; used = used + (hands_used or 0) end
            end
            local p, lo, hi = PR.wilson(wins, n)
            cand.p_clear, cand.lo, cand.hi, cand.n = p, lo, hi, n
            -- hands needed when winning: fewer hands left unused = less money ($1 per hand left)
            cand.hands_used = wins > 0 and used / wins or math.huge
            if cand.ref then cand.ref.p_clear = p; cand.ref.p_lo = lo; cand.ref.p_hi = hi; cand.ref.sim_n = n end
        end
        table.sort(candidates, function(a, b)
            if math.abs(a.p_clear - b.p_clear) > 1e-9 then return a.p_clear > b.p_clear end
            -- tie: win with fewer hands (more money), then prefer playing (keeps discards),
            -- then the higher immediate score, then fewer cards spent
            if math.abs(a.hands_used - b.hands_used) > 0.05 then return a.hands_used < b.hands_used end
            if a.type ~= b.type then return a.type == 'play' end
            local ma, mb = (a.ref and a.ref.mean or 0), (b.ref and b.ref.mean or 0)
            if ma ~= mb then return ma > mb end
            return #a.cards < #b.cards
        end)
        local best = candidates[1]
        if best then
            res.round = { p_clear = best.p_clear, method = 'monte_carlo', n = best.n, lo = best.lo, hi = best.hi }
            res.recommendation = { type = best.type, ref = best.ref, cards = best.cards, p_clear = best.p_clear,
                lo = best.lo, hi = best.hi, method = 'monte_carlo', n = best.n }
        end
        res.candidates = candidates
    end
    res.total_ms = (U.now() - t0) * 1000
    return res
end

return HA
