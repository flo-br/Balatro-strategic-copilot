-- The big list of synergies (1.0.12): model/synergies_db.lua merged with model/builds_db.lua by
-- engine/builds.lua, the generic rules, the item bonuses in the shop, "Synergies à chercher".
local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    return F, BSCopilot.require('engine/builds'), BSCopilot.require('model/synergies_db'), BSCopilot.require('model/jokers_db')
end

local function has(list, pattern)
    for _, e in ipairs(list or {}) do if e.why:find(pattern, 1, true) then return e end end
end

local CLASSES = { planet = true, tarot = true, spectral = true, ['pack:Celestial'] = true, ['pack:Arcana'] = true,
    ['pack:Standard'] = true, ['pack:Buffoon'] = true, ['pack:Spectral'] = true }

function S.every_key_exists_and_no_duplicate(T)
    local _, BD, SDB, DB = env()
    local IT = BSCopilot.require('model/items_db')
    local DBB = BSCopilot.require('model/builds_db')
    local seen = {}
    local function id(a, b) if a > b then a, b = b, a end return a .. '|' .. b end
    for _, list in ipairs({ DBB.PAIRS, SDB.PAIRS }) do
        for _, p in ipairs(list) do
            T.ok(DB.get(p[1]) and DB.get(p[2]), 'unknown joker: ' .. p[1] .. ' / ' .. p[2])
            T.ok(p[1] ~= p[2], 'self pair ' .. p[1])
            T.ok(DBB.STRENGTH[p[3]], 'tier ' .. tostring(p[3]))
            T.ok(type(p[4]) == 'string' and p[4] ~= '', 'reason of ' .. p[1] .. ' + ' .. p[2])
            T.ok(not seen[id(p[1], p[2])], 'duplicate pair ' .. id(p[1], p[2]))
            seen[id(p[1], p[2])] = true
        end
    end
    T.eq(#BD.PAIRS, #DBB.PAIRS + #SDB.PAIRS, 'every pair merged')
    for _, p in ipairs(SDB.ITEMS) do
        local k = p[2]
        T.ok(DB.get(p[1]), 'unknown joker ' .. p[1])
        local ok = CLASSES[k] or (k:match('^c_') and IT.consumable(k)) or (k:match('^v_') and IT.VOUCHERS[k])
        T.ok(ok, 'unknown item ' .. k)
        T.ok(SDB.ITEM_NAMES[k], 'no name for ' .. k)
        T.ok(DBB.STRENGTH[p[3]], 'tier ' .. tostring(p[3]))
    end
    local bkeys = {}
    for _, b in ipairs(BD.BUILDS) do
        T.ok(not bkeys[b.key], 'build key twice: ' .. b.key)
        bkeys[b.key] = true
        for _, l in ipairs({ b.core, b.support, b.anti or {} }) do
            for _, k in ipairs(l) do T.ok(DB.get(k), b.key .. ': unknown joker ' .. k) end
        end
    end
    -- every joker of the base game has at least one listed synergy
    local covered = {}
    for _, p in ipairs(BD.PAIRS) do covered[p.a] = true; covered[p.b] = true end
    for k in pairs(BD.ITEMS_OF_JOKER) do covered[k] = true end
    local missing = {}
    for _, k in ipairs(DB.all_keys()) do if not covered[k] then missing[#missing + 1] = k end end
    T.eq(#missing, 0, 'jokers without synergy: ' .. table.concat(missing, ' '))
    T.ok(#BD.PAIRS >= 350, 'a big list: ' .. #BD.PAIRS .. ' pairs')
end

function S.named_pairs_and_generic_rules(T)
    local F, BD = env()
    -- 1.0.12 list: Blueprint copies The Duo
    local _, _, list = BD.joker_bonus('j_blueprint', F.state({ ante = 4, jokers = { F.joker('j_duo') } }))
    T.ok(has(list, '×2 de plus sur chaque paire'))
    -- generic: two Pair jokers no list names together
    local v, l2 = BD.synergies('j_jolly', F.state({ ante = 4, jokers = { F.joker('j_sly') } }))
    T.ok(has(l2, 'même main : Paire') and v > 0, 'Jolly + Sly')
    -- a Three of a Kind contains a Pair
    _, l2 = BD.synergies('j_zany', F.state({ ante = 4, jokers = { F.joker('j_jolly') } }))
    T.ok(has(l2, 'déclenche aussi'), 'Zany + Jolly')
    -- same suit, different suits, Smeared Joker
    _, l2 = BD.synergies('j_wrathful_joker', F.state({ ante = 4, jokers = { F.joker('j_blackboard') } }))
    T.ok(has(l2, 'Blackboard : cartes Pique'), 'Wrathful + Blackboard')
    _, l2 = BD.synergies('j_lusty_joker', F.state({ ante = 4, jokers = { F.joker('j_seeing_double') } }))
    T.ok(not has(l2, 'couleurs différentes'), 'Seeing Double wants mixed suits')
    v, l2 = BD.synergies('j_wrathful_joker', F.state({ ante = 4, jokers = { F.joker('j_lusty_joker') } }))
    T.ok(has(l2, 'couleurs différentes') and v < 0, 'Spades + Hearts pull the deck two ways')
    v = BD.synergies('j_wrathful_joker', F.state({ ante = 4, jokers = { F.joker('j_gluttenous_joker'), F.joker('j_smeared') } }))
    T.ok(v > 0, 'Smeared Joker: Spades and Clubs together')
    -- hand_size is not a hand type
    _, l2 = BD.synergies('j_juggler', F.state({ ante = 4, jokers = { F.joker('j_troubadour') } }))
    T.ok(not has(l2, 'même main'), 'Juggler + Troubadour are not "the same hand"')
    -- a copy joker wants a Blueprint-compatible target
    T.eq((BD.synergies('j_blueprint', F.state({ ante = 4, jokers = { F.joker('j_joker') } }))), 0, 'nothing worth copying')
    -- with the list off, only builds_db and the generic rules count
    local was = BD.LIST_SCALE
    BD.LIST_SCALE = 0
    _, list = BD.synergies('j_blueprint', F.state({ ante = 4, jokers = { F.joker('j_duo') } }))
    BD.LIST_SCALE = was
    T.ok(not has(list, '×2 de plus sur chaque paire'), 'LIST_SCALE = 0: shown nowhere in the notes')
end

function S.vouchers_bought_and_cards_held_count(T)
    local F, BD = env()
    local v, l = BD.synergies('j_perkeo', F.state({ ante = 4, vouchers = { v_observatory = true } }))
    T.ok(has(l, 'planètes copiées') and v >= 0.4, 'Perkeo with Observatory bought: S')
    _, l = BD.synergies('j_baron', F.state({ ante = 4, consumables = { { key = 'c_cryptid', set = 'Spectral' } } }))
    T.ok(has(l, 'deux copies du meilleur Roi'), 'Baron with a Cryptid held')
end

function S.items_feed_the_jokers_owned(T)
    local F, BD = env()
    local s = F.state({ ante = 4, jokers = { F.joker('j_steel_joker') } })
    local v, why = BD.item_bonus({ key = 'c_chariot', set = 'Tarot' }, s)
    T.ok(v > 0 and why:find('Steel Joker', 1, true), tostring(why))
    v, why = BD.item_bonus({ key = 'c_jupiter', set = 'Planet' }, F.state({ jokers = { F.joker('j_constellation') } }))
    T.ok(v > 0 and why:find('Constellation', 1, true), 'any planet with Constellation')
    v = BD.item_bonus({ key = 'p_standard_normal_1', set = 'Booster', kind = 'Standard' }, F.state({ jokers = { F.joker('j_erosion') } }))
    T.ok(v < 0, 'a Standard pack against Erosion')
    T.eq((BD.item_bonus({ key = 'c_chariot', set = 'Tarot' }, F.state({}))), 0, 'no joker, no synergy')
end

function S.the_shop_notes_follow_the_items(T)
    local F, BD = env()
    local C = BSCopilot.require('model/cards')
    local SH = BSCopilot.require('engine/shop')
    local function notes(scale)
        local s = F.state({ dollars = 20, ante = 3, jokers = { F.joker('j_constellation') } })
        s.phase = 'shop'
        s.full_deck = C.standard_deck()
        s.shop = { jokers = { { uid = 'jup', set = 'Planet', key = 'c_jupiter', name = 'Jupiter', cost = 3, hand_type = 'Flush' } },
            vouchers = {}, boosters = { { uid = 'cel', set = 'Booster', key = 'p_celestial_normal_1', name = 'Celestial Pack', kind = 'Celestial', cost = 4 } } }
        local was = BD.ITEM_SCALE
        BD.ITEM_SCALE = scale
        local ok, r = pcall(SH.analyse, s, { n = 16 })
        BD.ITEM_SCALE = was
        assert(ok, r)
        local out = {}
        for _, o in ipairs(r.options) do if o.uid then out[o.uid] = o end end
        return out
    end
    local off, on = notes(0), notes(1)
    T.ok(on.jup.note > off.jup.note, string.format('Jupiter %d -> %d with Constellation', off.jup.note, on.jup.note))
    T.ok(on.cel.note > off.cel.note, string.format('Celestial pack %d -> %d', off.cel.note, on.cel.note))
    local said = false
    for _, r in ipairs(on.jup.reasons) do if r:find('Constellation', 1, true) then said = true end end
    T.ok(said, 'the reason names Constellation')
end

function S.pieces_to_look_for(T)
    local F, BD = env()
    local s = F.state({ ante = 3, jokers = { F.joker('j_baron') } })
    local w = BD.wanted(s, 4)
    T.eq(w[1].tier, 'S')
    local names = {}
    for _, e in ipairs(w) do names[e.name] = e end
    T.ok(names.Mime, 'Mime for Baron')
    -- shown in the shop panel (plan lines)
    local FS = BSCopilot.require('ui/format_strategy')
    local txt = {}
    for _, l in ipairs(FS.plan_lines({ wanted = w }, s)) do for _, sg in ipairs(l) do txt[#txt + 1] = sg.t end end
    txt = table.concat(txt, ' ')
    T.ok(txt:find('Synergies à chercher', 1, true) and txt:find('Mime (S, avec Baron)', 1, true), txt)
    -- nothing owned: nothing to look for
    T.eq(#BD.wanted(F.state({}), 4), 0)
end

function S.the_doc_is_up_to_date(T)
    local DOC = loadfile(T.REPO_ROOT .. '/tools/synergies_doc.lua')('--module')
    local f = io.open(T.REPO_ROOT .. '/docs/SYNERGIES.md', 'rb')
    T.ok(f, 'docs/SYNERGIES.md')
    local text = f:read('*a'); f:close()
    T.ok(text == DOC.render(), 'docs/SYNERGIES.md is stale: luajit tools/synergies_doc.lua docs/SYNERGIES.md')
end

return S
