local T = ...
local S = {}

local function setup(opts)
    local FG = dofile(T.REPO_ROOT .. '/tests/integration/fake_game.lua')
    opts = opts or {}
    opts.mod_root = T.MOD_ROOT
    FG.install(opts)
    return FG
end

function S.detects_other_mods(T)
    local FG = setup()
    SMODS.Mods.Cryptid = { id = 'Cryptid', name = 'Cryptid', can_load = true }
    SMODS.Mods.Steamodded = { id = 'Steamodded', can_load = true }
    local CM = BSCopilot.require('game/compat')
    local mods = CM.scan()
    T.eq(#mods, 1); T.eq(mods[1], 'Cryptid'); T.eq(CM.level, 'partial')
    FG.uninstall()
end

function S.talisman_numbers(T)
    local FG = setup()
    local CM = BSCopilot.require('game/compat')
    _G.to_number = function(big) return big.value end
    T.eq(CM.num({ value = 1234 }, 0), 1234)
    T.eq(CM.num(5, 0), 5)
    T.eq(CM.num('7', 0), 7)
    T.eq(CM.num(nil, 3), 3)
    _G.to_number = nil
    -- the reader uses it: chips as a big-number table
    _G.to_number = function(big) return big.value end
    G.GAME.chips = { value = 999 }
    local SR = BSCopilot.require('game/state_reader')
    T.eq(SR.snapshot().blind.chips_scored, 999)
    _G.to_number = nil
    FG.uninstall()
end

function S.native_hand_cross_check(T)
    local FG = setup()
    local CM = BSCopilot.require('game/compat')
    local C = BSCopilot.require('model/cards')
    local norm = C.parse_list('Ah Ad')
    G.FUNCS.get_poker_hand_info = function(cards) return 'Pair' end
    local same = CM.cross_check_hand({ {}, {} }, norm, {})
    T.eq(same, true)
    -- a mod adds a hand the engine does not know
    G.FUNCS.get_poker_hand_info = function(cards) return 'Mod Pair Plus' end
    local same2, native = CM.cross_check_hand({ {}, {} }, norm, {})
    T.eq(same2, false); T.eq(native, 'Mod Pair Plus')
    FG.uninstall()
end

function S.repeated_score_mismatch_downgrades_exact(T)
    local FG = setup()
    local CM = BSCopilot.require('game/compat')
    CM.score_mismatches, CM.hand_mismatches, CM.mods = 0, 0, {}
    CM.update_level()
    T.ok(CM.trust_exact())
    CM.record_score(100, 100, true)
    T.ok(CM.trust_exact())
    CM.record_score(100, 150, true)
    CM.record_score(200, 260, true)
    T.no(CM.trust_exact(), 'exact labels withdrawn after 2 mismatches')
    local Fmt = BSCopilot.require('ui/format')
    T.ok(Fmt.score_text({ mean = 100, min = 100, max = 100, complete = true }):find('partiel'))
    FG.uninstall()
end

function S.learned_multiplier_for_unknown_joker(T)
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local C = BSCopilot.require('model/cards')
    local Score = BSCopilot.require('engine/score')
    local s = F.state({ jokers = { { key = 'j_mod', name = 'Mod Joker', ability = {} } } })
    s.learned_multipliers = { j_mod = 2 }
    local r = Score.evaluate(s, C.parse_list('Ah Ad'), {})
    T.eq(r.mean, 128)
    T.no(r.exact)
    T.eq(r.coverage.learned[1], 'Mod Joker')
end

return S
