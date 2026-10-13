-- Balatro Strategic Copilot - engine/synergy.lua  (JokerSynergyAnalyzer)
-- * themes of the build (hands actually played by the policy, suits, ranks, enhancements);
-- * active synergies, detected by rules on the real build;
-- * potential synergy of a candidate joker with the build (no hypothetical bonus for
--   synergies that the current build cannot exploit);
-- * marginal contribution of each joker, MEASURED with the score engine on the same sample
--   hands (score with vs without the joker);
-- * best joker order (exhaustive for <= 6 order-sensitive jokers, else local search).

local BSC = BSCopilot
local U = BSC.require('core/util')
local C = BSC.require('model/cards')
local DB = BSC.require('model/jokers_db')
local Score = BSC.require('engine/score')

local SY = {}

local function noop() end

-- Themes ----------------------------------------------------------------------------------
function SY.themes(state, ps)
    local th = { hand = {}, suit = {}, tags = {}, deck = state.full_deck_stats or {} }
    if ps then
        local total = 0
        for _, v in pairs(ps.usage or {}) do total = total + v end
        for k, v in pairs(ps.usage or {}) do th.hand[k] = v / math.max(1, total) end
    end
    local st = th.deck
    local size = math.max(1, st.size or 52)
    for s, n in pairs(st.suits or {}) do th.suit[s] = n / size end
    th.faces = (st.faces or 0) / size
    for _, j in ipairs(state.jokers or {}) do
        local d = DB.get(j.key, j.name)
        if d then for _, t in ipairs(d.tags) do th.tags[t] = (th.tags[t] or 0) + 1 end end
    end
    return th
end

-- How well a joker definition fits the build: score in [0,1] + reasons (keys for i18n/text).
function SY.fit(def, th)
    if not def then return 0, {} end
    local score, reasons = 0, {}
    local function add(v, why) score = score + v; reasons[#reasons + 1] = why end
    for _, t in ipairs(def.tags) do
        local hand = t:match('^hand_(.+)$')
        if hand then
            local f = th.hand[hand] or 0
            -- contained hands also count (a Full House contains a Pair...)
            if hand == 'Pair' then f = f + (th.hand['Two Pair'] or 0) + (th.hand['Full House'] or 0) + (th.hand['Three of a Kind'] or 0) * 0.8 end
            if hand == 'Flush' then f = f + (th.hand['Straight Flush'] or 0) end
            if hand == 'Straight' then f = f + (th.hand['Straight Flush'] or 0) end
            if f > 0.25 then add(math.min(0.6, f), 'joue souvent ' .. hand) end
        end
        local suit = t:match('^suit_(%u%l+)$')
        if suit and th.suit[suit] then
            local f = th.suit[suit]
            if f > 0.3 then add(math.min(0.5, (f - 0.25) * 2), 'deck orienté ' .. suit) end
        end
        if t == 'faces' and (th.faces or 0) > 0.28 then add(0.2, 'beaucoup de figures') end
        if t == 'faces' and (th.tags.faces or 0) > 0 then add(0.15, 'autres jokers de figures') end
        if t == 'deck_steel' and (th.deck.steel or 0) >= 2 then add(0.4, 'cartes acier dans le deck') end
        if t == 'deck_stone' and (th.deck.stone or 0) >= 2 then add(0.3, 'cartes pierre dans le deck') end
        if t == 'gold' and (th.deck.gold or 0) >= 2 then add(0.3, 'cartes or dans le deck') end
        if t == 'glass' and (th.deck.glass or 0) >= 2 then add(0.3, 'cartes verre dans le deck') end
        if t == 'lucky' and (th.deck.lucky or 0) >= 2 then add(0.3, 'cartes chance dans le deck') end
        if t == 'enhanced_deck' and (th.deck.enhanced or 0) >= 10 then add(0.4, 'deck très amélioré') end
        if t == 'xmult' and ((th.tags.mult or 0) + (th.tags.chips or 0)) >= 2 then add(0.2, 'multiplie une base déjà solide') end
        if (t == 'mult' or t == 'chips') and (th.tags.xmult or 0) >= 1 then add(0.1, 'nourrit les multiplicateurs') end
        if t == 'retrigger' and (th.tags.mult or 0) + (th.tags.xmult or 0) >= 2 then add(0.2, 'redéclenche des effets par carte') end
        if t == 'copy' and (th.tags.xmult or 0) >= 1 then add(0.3, 'copie un multiplicateur') end
        if t == 'held' and (th.tags.held or 0) >= 1 then add(0.2, 'synergie cartes en main') end
    end
    return U.clamp(score, 0, 1), reasons
end

-- Active synergies in the current build (descriptive).
function SY.active(state, ps)
    local th = SY.themes(state, ps)
    local out = {}
    for _, j in ipairs(state.jokers or {}) do
        local d = DB.get(j.key, j.name)
        if d and not j.debuff then
            local f, reasons = SY.fit(d, th)
            if f >= 0.3 then out[#out + 1] = { name = j.name, fit = f, reasons = reasons } end
        end
    end
    table.sort(out, function(a, b) return a.fit > b.fit end)
    return out, th
end

-- Measured contributions --------------------------------------------------------------------
-- ps must come from strategy.power_samples(..., { keep_plays = true }).
local function mean_score(P, plays, check)
    local tot, n = 0, 0
    local Plast = Score.derive(P, { hands_left = 1 })
    for _, pl in pairs(plays) do
        check()
        local rng = BSC.require('core/rng').new('contrib')
        local s = Score.quick(pl.last and Plast or P, pl.played, pl.held, rng, 1)
        tot = tot + s; n = n + 1
    end
    return n > 0 and tot / n or 0
end

local function with_jokers(state, jokers)
    local s = {}
    for k, v in pairs(state) do s[k] = v end
    s.jokers = jokers
    return s
end

function SY.contributions(state, ps, task)
    local check = (task and task.check) or noop
    if not ps or not ps.plays then return {} end
    local base = mean_score(Score.prepare(ps.prepared and ps.prepared.state or state), ps.plays, check)
    local out = {}
    local jokers = state.jokers or {}
    for i, j in ipairs(jokers) do
        local rest = {}
        for k, jj in ipairs(jokers) do if k ~= i then rest[#rest + 1] = jj end end
        local st = with_jokers(ps.prepared and ps.prepared.state or state, rest)
        local without = mean_score(Score.prepare(st), ps.plays, check)
        local ratio = (without > 0) and (base / without) or (base > 0 and math.huge or 1)
        out[i] = { name = j.name, key = j.key, with = base, without = without, ratio = ratio,
            share = (base > 0) and (1 - without / base) or 0 }
    end
    return out, base
end

-- Order optimization --------------------------------------------------------------------------
local function order_sensitive(state)
    local n = 0
    for _, j in ipairs(state.jokers or {}) do
        local d = DB.get(j.key, j.name)
        if j.edition == 'e_polychrome' then n = n + 1
        elseif d then
            for _, t in ipairs(d.tags) do if t == 'xmult' or t == 'copy' then n = n + 1; break end end
        end
    end
    return n > 0
end
SY.order_sensitive = order_sensitive

local function permutations(n, f)
    local a = {}
    for i = 1, n do a[i] = i end
    local function rec(k)
        if k > n then f(a); return end
        for i = k, n do
            a[k], a[i] = a[i], a[k]
            rec(k + 1)
            a[k], a[i] = a[i], a[k]
        end
    end
    rec(1)
end

function SY.best_order(state, ps, task)
    local check = (task and task.check) or noop
    local jokers = state.jokers or {}
    if #jokers < 2 or not ps or not ps.plays or not order_sensitive(state) then return nil end
    for _, j in ipairs(jokers) do if j.face_down then return nil end end
    local base_state = ps.prepared and ps.prepared.state or state
    local current = mean_score(Score.prepare(base_state), ps.plays, check)
    local best_order, best = nil, current
    local function eval(order)
        local js = {}
        for i, k in ipairs(order) do js[i] = jokers[k] end
        local v = mean_score(Score.prepare(with_jokers(base_state, js)), ps.plays, check)
        if v > best * 1.0000001 then
            best = v
            best_order = {}
            for i, k in ipairs(order) do best_order[i] = k end
        end
    end
    if #jokers <= 5 then
        permutations(#jokers, eval)
    else
        -- local search with adjacent swaps (bounded)
        local order = {}
        for i = 1, #jokers do order[i] = i end
        local improved = true
        local iter = 0
        while improved and iter < 30 do
            improved = false
            iter = iter + 1
            for i = 1, #order - 1 do
                for k = i + 1, #order do
                    order[i], order[k] = order[k], order[i]
                    local before = best
                    eval(order)
                    if best > before then improved = true else order[i], order[k] = order[k], order[i] end
                end
            end
        end
    end
    if not best_order or current <= 0 then return nil end
    local names = {}
    for i, k in ipairs(best_order) do names[i] = jokers[k].name end
    return { order = best_order, names = names, gain = best / current - 1, current = current, best = best }
end

return SY
