-- Balatro Strategic Copilot - learning/observe.lua  ("Je joue, tu apprends", 1.0.14)
-- The player plays; the copilot watches. For every action the game reports (bought, sold,
-- rerolled, left the shop, took a pack card, used a consumable, played or discarded cards,
-- skipped a blind), the copilot compares it with the step it would have advised for that
-- exact state (computed when the analysis of the state finished, never shown in this mode)
-- and learns from the differences (learning/feedback.lua, FB.observe: bounded preferences,
-- half the weight of a correction given with the X key). It only READS the game.

local BSC = BSCopilot
local FB = BSC.require('learning/feedback')

local OB = { last = {} }

-- advice of the moment: the step for this state (the analysis is complete)
function OB.on_analysis(phase, result, state, cfg)
    if not phase or not state then return end
    local A = BSC.require('engine/advice')
    local ok, step = pcall(A.step, phase, state, result, cfg, false)
    if ok then OB.last[phase] = { step = step, state = state } end
end

local function find(list, uid)
    for _, x in ipairs(list or {}) do if tostring(x.uid) == tostring(uid) then return x end end
end

local function item_of(state, uid)
    local sh = state.shop or {}
    local x = find(sh.jokers, uid) or find(sh.vouchers, uid) or find(sh.boosters, uid)
    if x then return FB.item_brief(x, 'shop') end
    x = find(state.pack and state.pack.cards, uid)
    if x then return FB.item_brief(x, 'pack') end
    x = find(state.jokers, uid)
    if x then return FB.item_brief(x, 'joker') end
    x = find(state.consumables, uid)
    if x then return FB.item_brief(x, 'consumable') end
    return nil
end

local LABEL = {
    buy = 'Acheter %s', take = 'Prendre %s', reroll = 'Relancer la boutique', leave = 'Ne rien acheter : blinde suivante',
    sell = 'Vendre %s', use = 'Utiliser %s', play = 'Jouer ces cartes', discard = 'Défausser ces cartes',
    skip_blind = 'Passer la blinde', play_blind = 'Jouer la blinde',
}

-- Observation of an action taken from `state` (the state the advice was computed for).
-- Returns the observation (FB.observe input), or nil when the advice of that state is unknown.
function OB.observation(action, state, ev)
    if not state or not state.phase then return nil end
    local last = OB.last[state.phase]
    if not last or last.state ~= state or not last.step then return nil end
    local item = ev and ev.uid and item_of(state, ev.uid) or nil
    local label = LABEL[action] or action
    if label:find('%s', 1, true) then label = label:format(tostring(item and item.name or (ev and ev.key) or '?')) end
    local run = state.run or {}
    return { phase = state.phase, ante = run.ante, round = run.round, stake = run.stake, deck = run.deck_key,
        dollars = state.econ and state.econ.dollars, advice = FB.advice_brief(last.step, state), action = action,
        item = item, uids = ev and ev.uids, label = label }
end

-- action of a game event (game/controller.lua events, native or rebuilt by polling)
local ACTION = { buying_card = 'buy', open_booster = 'buy', reroll_shop = 'reroll', selling_card = 'sell',
    using_consumeable = 'use', skip_blind = 'skip_blind', before = 'play', pre_discard = 'discard' }

function OB.on_event(ev, state)
    local action = ev and ACTION[ev.kind]
    if not action then return nil end
    if action == 'buy' and state and state.phase == 'pack' then action = 'take' end
    return OB.observation(action, state, ev)
end

-- state changes: leaving the shop without buying what was advised is a choice too
function OB.on_state(prev, s)
    if prev and s and prev.phase == 'shop' and s.phase == 'blind_select' then
        return OB.observation('leave', prev, nil)
    end
    return nil
end

return OB
