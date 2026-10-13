local T = ...
local S = {}

local function setup(opts)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    opts = opts or {}
    opts.mod_root = T.MOD_ROOT
    FG.install(opts)
    local SR = BSCopilot.require('game/state_reader')
    return FG, SR
end

function S.reads_core_state(T)
    local FG, SR = setup({ dollars = 12, hands_left = 3, discards_left = 2, required = 450, ante = 2 })
    local s = SR.snapshot()
    T.eq(s.phase, 'hand')
    T.eq(s.run.ante, 2); T.eq(s.econ.dollars, 12); T.eq(s.round.hands_left, 3); T.eq(s.round.discards_left, 2)
    T.eq(s.blind.chips_required, 450); T.eq(s.blind.key, 'bl_small')
    T.eq(#s.hand_cards, 8); T.eq(s.hand_cards[1].rank, 'Ace'); T.eq(s.hand_cards[1].suit, 'Hearts')
    T.eq(s.hands.Pair.chips, 10)
    T.eq(s.meta.game_version, '1.0.1o-FULL'); T.eq(s.meta.smods_version, '26.1002.0')
    T.eq(s.targets.idol.id, 14); T.eq(s.targets.ancient_suit, 'Spades')
    T.eq(#s.upcoming, 3); T.eq(s.upcoming[3].key, 'bl_hook'); T.eq(s.upcoming[3].chips, 1600) -- ante 2: 800 x 2
    T.eq(next(s.errors), nil, 'no section failed')
    T.ok(s.read_ms < 50)
    FG.uninstall()
end

function S.deck_order_is_not_leaked(T)
    local FG, SR = setup()
    local s1 = SR.snapshot()
    -- shuffle the real draw pile: the snapshot must be identical (composition only)
    local cards = G.deck.cards
    for i = #cards, 2, -1 do local j = (i * 7) % i + 1; cards[i], cards[j] = cards[j], cards[i] end
    local s2 = SR.snapshot()
    local J = BSCopilot.require('core/json')
    T.eq(J.encode(s1.deck), J.encode(s2.deck))
    FG.uninstall()
end

function S.face_down_cards_hidden(T)
    local FG, SR = setup()
    G.hand.cards[3].facing = 'back'
    local s = SR.snapshot()
    local c = s.hand_cards[3]
    T.ok(c.face_down); T.eq(c.rank, nil); T.eq(c.suit, nil)
    T.eq(s.knowledge.hidden_hand_cards, 1)
    FG.uninstall()
end

function S.enhancements_editions_seals(T)
    local FG, SR = setup()
    local card = FG.card('Ks', { enh = 'm_glass', seal = 'Red', edition = { type = 'polychrome', polychrome = true } })
    G.hand.cards[1] = card
    local s = SR.snapshot()
    local c = s.hand_cards[1]
    T.eq(c.enh, 'm_glass'); T.eq(c.x_mult, 2); T.eq(c.seal, 'Red'); T.eq(c.edition, 'e_polychrome')
    local modded = FG.card('Qs', { enh = 'm_mymod_weird' })
    G.hand.cards[2] = modded
    s = SR.snapshot()
    T.ok(s.hand_cards[2].unknown_enh, 'modded enhancement flagged')
    FG.uninstall()
end

function S.jokers_and_shop(T)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    FG.install({ mod_root = T.MOD_ROOT, state = 5,
        jokers = { FG.joker('j_joker', 'Joker', { mult = 4 }), FG.joker('j_mymod_x', 'Modded X', {}) },
        shop = { FG.joker('j_duo', 'The Duo', { x_mult = 2, type = 'Pair' }, { rarity = 3, cost = 8 }) } })
    local SR = BSCopilot.require('game/state_reader')
    local s = SR.snapshot()
    T.eq(s.phase, 'shop')
    T.eq(#s.jokers, 2); T.ok(s.jokers[1].known); T.no(s.jokers[2].known)
    T.eq(s.shop.jokers[1].set, 'Joker'); T.eq(s.shop.jokers[1].joker.key, 'j_duo'); T.eq(s.shop.jokers[1].cost, 8)
    FG.uninstall()
end

function S.never_raises_on_broken_game(T)
    local FG, SR = setup()
    G.GAME.current_round = nil
    G.jokers = 42
    G.GAME.hands = { Pair = 'broken' }
    local ok, s = pcall(SR.snapshot)
    T.ok(ok, tostring(s))
    T.eq(type(s.hands.Pair.chips), 'number', 'garbage degrades to safe values')
    -- an accessor that raises is contained in its section and reported
    setmetatable(G.GAME.blind, { __index = function() error('boom') end })
    G.GAME.blind.name = nil
    local ok2, s2 = pcall(SR.snapshot)
    T.ok(ok2)
    T.ok(s2.errors.blind ~= nil, 'error reported for the blind section')
    T.ok(s2.econ ~= nil, 'other sections still read')
    FG.uninstall()
end

return S
