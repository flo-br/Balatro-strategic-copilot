-- Journal of the runs (1.1.1, learning/journal.lua): every move of the run in a text file the
-- player can send, to learn from winning runs (blinds and tags, shops with the copilot's notes,
-- purchases, packs, consumables and what they changed, hands with their score).
local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local C = BSCopilot.require('model/cards')
    local JN = BSCopilot.require('learning/journal')
    local lines = {}
    local jn = JN.new(function(l) lines[#lines + 1] = l end, { now = function() return 0 end })
    return F, C, JN, jn, lines
end

local function has(lines, txt)
    for _, l in ipairs(lines) do if l:find(txt, 1, true) then return l end end
    return nil
end

local function cards(C, str, uid0)
    local out = C.parse_list(str)
    for i, c in ipairs(out) do c.uid = (uid0 or 'c') .. i end
    return out
end

function S.blinds_tags_and_skips(T)
    local F, C, JN, jn, lines = env()
    local s = F.state({ ante = 2, stake = 7, dollars = 9 })
    s.phase = 'blind_select'; s.run.seed = 'ABC123'; s.run.deck_name = 'Red Deck'
    s.upcoming = { { slot = 'Small', name = 'Small Blind', chips = 800, state = 'Select' },
        { slot = 'Big', name = 'Big Blind', chips = 1200, state = 'Upcoming' },
        { slot = 'Boss', name = 'The Hook', chips = 1600, boss = true, state = 'Upcoming' } }
    s.blind_tag_names = { Small = 'Investment Tag', Big = 'Charm Tag' }
    jn:on_state(nil, s, true)
    T.ok(has(lines, '=== Partie') and has(lines, 'mise 7') and has(lines, 'ABC123') and has(lines, 'vous jouez seul'), table.concat(lines, '\n'))
    local l = has(lines, 'CHOIX DE BLINDE')
    T.ok(l and l:find('Small Blind 800 jetons (tag Investment Tag)', 1, true) and l:find('The Hook 1600', 1, true), l)
    T.ok(l:find('^A2 M1 9 %$ |'), l)
    -- the skip, with the tag taken and the advice of that state
    jn:on_analysis('blind_select', {}, s, { action = 'select_blind', label = 'JOUER', text = 'Jouer la blinde' })
    jn:on_event({ kind = 'skip_blind' }, s)
    l = has(lines, 'passe la Small Blind')
    T.ok(l and l:find('tag Investment Tag', 1, true) and l:find('[conseil : Jouer la blinde]', 1, true), l)
    -- the same state seen again: the line is not repeated
    local n = #lines
    jn:on_state(s, s, true)
    T.eq(#lines, n, 'no repeat')
    -- key O pressed again during the run: written once
    jn:on_state(s, s, false)
    jn:on_state(s, s, false)
    T.eq(#lines, n + 1); T.ok(lines[#lines]:find('mode : conseils affichés', 1, true), lines[#lines])
end

function S.hands_played_with_their_score(T)
    local F, C, JN, jn, lines = env()
    local hand = cards(C, 'Kh Ks 7d 2c 9s', 'h')
    hand[3].enh = 'm_steel'
    local s = F.state({ ante = 1, required = 300, scored = 0, hand_cards = hand, jokers = { F.joker('j_jolly', nil, { uid = 'j1' }) },
        levels = { Pair = 3 } })
    s.blind.name = 'Small Blind'
    jn:on_state(nil, s, false)
    local l = has(lines, 'BLINDE Small Blind')
    T.ok(l and l:find('300 jetons, 4 mains, 3 défausses', 1, true), l)
    l = has(lines, 'jokers : Jolly Joker')
    T.ok(l and l:find('Paire 3', 1, true), l)
    -- played: the hand found from the cards (no name from the game in polling mode), the cards kept
    jn:on_event({ kind = 'before', uids = { 'h1', 'h2' }, chips_before = 0 }, s)
    l = has(lines, 'joue Paire')
    T.ok(l and l:find('R♥ R♠', 1, true) and l:find('garde : 7♦(acier)', 1, true), l)
    -- the score once the game shows it
    local s2 = F.state({ ante = 1, required = 300, scored = 180, hand_cards = hand, jokers = s.jokers })
    s2.blind.name = 'Small Blind'
    jn:on_state(s, s2, false)
    l = has(lines, '→ 180 jetons')
    T.ok(l and l:find('total 180 / 300', 1, true), l)
    jn:on_event({ kind = 'pre_discard', uids = { 'h4', 'h5' } }, s2)
    T.ok(has(lines, 'défausse : 2♣ 9♠'), table.concat(lines, '\n'))
    -- the blind won
    local s3 = F.state({ ante = 1, scored = 420 }); s3.phase = 'round_eval'
    jn:on_state(s2, s3, false)
    l = has(lines, 'blinde gagnée')
    T.ok(l and l:find('Small Blind (420 / 300 jetons)', 1, true), l)
end

local function shop(F)
    local s = F.state({ ante = 2, dollars = 14, jokers = { F.joker('j_egg', nil, { uid = 'egg', eternal = true }) } })
    s.phase = 'shop'
    s.shop = { jokers = {
        { uid = 'duo', set = 'Joker', key = 'j_duo', name = 'The Duo', cost = 8, joker = F.joker('j_duo', nil, { uid = 'duo', edition = 'e_holo' }) },
        { uid = 'mer', set = 'Planet', key = 'c_mercury', name = 'Mercury', cost = 3, hand_type = 'Pair' },
    }, vouchers = { { uid = 'ov', set = 'Voucher', key = 'v_overstock_norm', name = 'Overstock', cost = 10 } },
        boosters = { { uid = 'arc', set = 'Booster', key = 'p_arcana_normal_1', name = 'Arcana Pack', cost = 4 } } }
    return s
end

function S.shops_offers_notes_and_moves(T)
    local F, C, JN, jn, lines = env()
    local s = shop(F)
    jn:on_state(nil, s, true)
    local l = has(lines, 'BOUTIQUE :')
    T.ok(l and l:find('The Duo (rare, holo), 8 $', 1, true) and l:find('Mercury (Paire), 3 $', 1, true)
        and l:find('Arcana Pack, 4 $', 1, true) and l:find('Overstock, 10 $', 1, true) and l:find('relance 5 $', 1, true), l)
    T.ok(has(lines, 'jokers : Egg (éternel)'), table.concat(lines, '\n'))
    -- the copilot's view once its analysis is done
    local r = { options = { { uid = 'duo', name = 'The Duo', note = 81.4 }, { uid = 'mer', name = 'Mercury', note = 52 } } }
    local step = { action = 'buy', label = 'À PRENDRE', text = 'Acheter The Duo (8 $)', targets = { 'duo' } }
    jn:on_analysis('shop', r, s, step)
    l = has(lines, 'avis du copilote')
    T.ok(l and l:find('Acheter The Duo (8 $)', 1, true) and l:find('The Duo 81, Mercury 52', 1, true), l)
    -- the player's moves, with the note and the advice of that very state
    jn:on_event({ kind = 'buying_card', uid = 'mer', key = 'c_mercury' }, s)
    l = has(lines, 'achète Mercury')
    T.ok(l and l:find('note 52', 1, true) and l:find('[conseil : Acheter The Duo (8 $)]', 1, true), l)
    jn:on_event({ kind = 'reroll_shop' }, s)
    T.ok(has(lines, 'relance la boutique (5 $)'), table.concat(lines, '\n'))
    jn:on_event({ kind = 'selling_card', uid = 'egg', sell_cost = 3 }, s)
    T.ok(has(lines, 'vend Egg (éternel) (+3 $)'), table.concat(lines, '\n'))
    -- an advice computed for another state is not used
    local other = shop(F)
    jn:on_event({ kind = 'reroll_shop' }, other)
    T.ok(not lines[#lines]:find('conseil', 1, true), lines[#lines])
    -- after a purchase (an offer gone, nothing new) the shop is not written again
    local bought = shop(F); table.remove(bought.shop.jokers, 2)
    jn:on_state(s, bought, true)
    T.eq(select(2, table.concat(lines, '\n'):gsub('BOUTIQUE :', '')), 1, 'not written again after a purchase')
    -- a reroll shows the new offers; leaving is written
    local s2 = shop(F); s2.shop.jokers[1].uid = 'duo2'
    jn:on_state(bought, s2, true)
    T.eq(select(2, table.concat(lines, '\n'):gsub('BOUTIQUE :', '')), 2, 'new offers after the reroll')
    local bs = F.state({ ante = 2 }); bs.phase = 'blind_select'
    jn:on_state(s2, bs, true)
    T.ok(has(lines, 'quitte la boutique'), table.concat(lines, '\n'))
end

function S.packs_and_what_the_cards_changed(T)
    local F, C, JN, jn, lines = env()
    local s = shop(F)
    jn:on_state(nil, s, true)
    jn:on_event({ kind = 'open_booster', uid = 'arc', key = 'p_arcana_normal_1' }, s)
    T.ok(has(lines, 'ouvre Arcana Pack, 4 $'), table.concat(lines, '\n'))
    local hand = cards(C, '2h 9s Kd', 'p')
    local deck = cards(C, '2h 9s Kd', 'p')
    local p = F.state({ ante = 2, dollars = 10, hand_cards = hand }); p.phase = 'pack'; p.full_deck = deck
    p.pack = { cards = { { uid = 'str', set = 'Tarot', key = 'c_strength', name = 'Strength' },
        { uid = 'emp', set = 'Tarot', key = 'c_empress', name = 'The Empress' } }, choices_left = 1 }
    jn:on_state(s, p, true)
    local l = has(lines, 'PAQUET Arcana Pack')
    T.ok(l and l:find('Strength ; The Empress', 1, true) and l:find('choix restants : 1', 1, true), l)
    T.ok(has(lines, 'main : 2♥ 9♠ R♦'), table.concat(lines, '\n'))
    -- taken on the 2 of Hearts (selected): the 2 became a 3
    hand[1].highlighted = true
    jn:on_event({ kind = 'buying_card', uid = 'str', key = 'c_strength' }, p)
    l = has(lines, 'prend Strength')
    T.ok(l and l:find('sur 2♥', 1, true), l)
    local after = shop(F); after.dollars = 10
    after.full_deck = cards(C, '3h 9s Kd', 'p')
    jn:on_state(p, after, true)
    l = has(lines, 'effet : 2♥ → 3♥')
    T.ok(l, table.concat(lines, '\n'))
    T.ok(not has(lines, 'passe le paquet'), 'taken: not passed')
    -- a pack left without taking anything
    jn:on_event({ kind = 'open_booster', uid = 'arc', key = 'p_arcana_normal_1' }, after)
    local p2 = F.state({ ante = 2 }); p2.phase = 'pack'; p2.pack = { cards = { { uid = 'x', set = 'Tarot', name = 'The Fool' } }, choices_left = 1 }
    jn:on_state(after, p2, true)
    jn:on_state(p2, shop(F), true)
    T.ok(has(lines, 'passe le paquet'), table.concat(lines, '\n'))
end

function S.consumables_and_the_end_of_the_run(T)
    local F, C, JN, jn, lines = env()
    local s = F.state({ ante = 5, dollars = 12, consumables = { { uid = 'her', key = 'c_hermit', name = 'The Hermit', set = 'Tarot' } } })
    s.phase = 'shop'; s.shop = { jokers = {}, vouchers = {}, boosters = {} }
    jn:on_state(nil, s, false)
    jn:on_event({ kind = 'using_consumeable', uid = 'her', key = 'c_hermit' }, s)
    T.ok(has(lines, 'utilise The Hermit'), table.concat(lines, '\n'))
    local s2 = F.state({ ante = 5, dollars = 24 }); s2.phase = 'shop'; s2.shop = s.shop
    jn:on_state(s, s2, false)
    T.ok(has(lines, 'effet : +12 $'), table.concat(lines, '\n'))
    -- a planet: the level
    local s3 = F.state({ ante = 5, dollars = 24, levels = { Flush = 4 } }); s3.phase = 'shop'; s3.shop = s.shop
    jn:on_event({ kind = 'using_consumeable', uid = 'jup', key = 'c_jupiter' }, s2)
    jn:on_state(s2, s3, false)
    T.ok(has(lines, 'Couleur niveau 4'), table.concat(lines, '\n'))
    -- victory, then the end
    local w = F.state({ ante = 9 }); w.phase = 'shop'; w.run.won = true; w.shop = s.shop
    jn:on_state(s3, w, false)
    T.ok(has(lines, '=== VICTOIRE'), table.concat(lines, '\n'))
    local h = F.state({ ante = 9, required = 100000, scored = 0 }); h.blind.name = 'The Wall'; h.run.won = true
    jn:on_state(w, h, false)
    local go = F.state({ ante = 9, scored = 80000 }); go.phase = 'game_over'; go.run.won = true
    jn:on_state(h, go, false)
    local l = has(lines, '=== FIN')
    T.ok(l and l:find('The Wall (80000 / 100000 jetons)', 1, true), l)
end

function S.file_size_cap_and_the_runtime(T)
    local P = BSCopilot.require('io/persistence')
    local JN = BSCopilot.require('learning/journal')
    local st = P.new(P.memory_backend())
    local w = JN.file_writer(st, 100)
    for i = 1, 60 do w('ligne ' .. i .. ' ' .. string.rep('x', 20)) end
    local path, old = st:path(JN.FILE), st:path(JN.OLD)
    T.ok(st.be.files[old] and #st.be.files[old] > 100, 'previous file kept')
    T.ok(#st.be.files[path] < #st.be.files[old], 'file restarted')
    -- the runtime writes it (learning.journal on by default), never when it is off
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local RT = BSCopilot.require('learning/runtime')
    local was_store, was_lr, was_cfg = BSCopilot.store, BSCopilot.learning_runtime, BSCopilot.config
    local listener
    local Ctl = { on = function(f) listener = f end, register = function() end, results = {}, state = nil, on_observed = function() end }
    local ok, err = pcall(function()
        BSCopilot.store = P.new(P.memory_backend())
        RT.attach(Ctl)
        local s = F.state({ ante = 1 }); s.phase = 'blind_select'; s.upcoming = { { slot = 'Small', name = 'Small Blind', chips = 300, state = 'Select' } }
        listener('state', { prev = nil, state = s })
        local text = BSCopilot.store.be.files[BSCopilot.store:path(JN.FILE)] or ''
        T.ok(text:find('=== Partie', 1, true) and text:find('CHOIX DE BLINDE', 1, true), text)
        BSCopilot.store = P.new(P.memory_backend())
        BSCopilot.config = setmetatable({ learning = { journal = false } }, { __index = was_cfg })
        RT.attach(Ctl)
        listener('state', { prev = nil, state = s })
        T.eq(BSCopilot.store.be.files[BSCopilot.store:path(JN.FILE)], nil, 'journal = false: not written')
    end)
    BSCopilot.store, BSCopilot.learning_runtime, BSCopilot.config = was_store, was_lr, was_cfg
    if not ok then error(err, 0) end
end

return S
