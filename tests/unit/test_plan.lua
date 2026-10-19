-- engine/plan.lua: the run's plan as top players reason about it (docs/PRO_LESSONS.md).
local T = ...
local S = {}

local function env()
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    return F, BSCopilot.require('engine/plan'), BSCopilot.require('model/jokers_db')
end

function S.kinds_and_multipliers(T)
    local F, PL, DB = env()
    T.eq(PL.joker_kind(DB.get('j_duo')), 'xmult')
    T.eq(PL.joker_kind(DB.get('j_blueprint')), 'xmult', 'Blueprint copies the best joker')
    T.eq(PL.joker_kind(DB.get('j_joker')), 'additive')
    T.eq(PL.joker_kind(DB.get('j_ride_the_bus')), 'scaling')
    T.eq(PL.joker_kind(DB.get('j_golden')), 'econ')
    local s = F.state({ ante = 5, jokers = { F.joker('j_duo'), F.joker('j_joker', nil, { edition = 'e_polychrome' }) } })
    local x = PL.xmult_sources(s)
    T.eq(x, 2, 'The Duo and a Polychrome joker')
end

function S.gaps_follow_the_antes(T)
    local F, PL = env()
    -- ante 3 with no multiplier: one is due at ante 4, so the plan already looks for it
    local p = PL.analyse(F.state({ ante = 3, jokers = { F.joker('j_joker'), F.joker('j_greedy_joker') } }))
    T.eq(p.gaps.xmult, 1); T.eq(p.phase, 'mid')
    -- ante 1 without jokers: the first scoring jokers come first
    p = PL.analyse(F.state({ ante = 1 }))
    T.ok(p.gaps.scoring)
    -- falling behind: a typical hand (measured without discards) below half the ante's base
    -- chips (5000 at ante 4)
    p = PL.analyse(F.state({ ante = 4, jokers = { F.joker('j_duo') } }), { median = 2000 })
    T.ok(p.falling_behind and p.gaps.power)
    p = PL.analyse(F.state({ ante = 4, jokers = { F.joker('j_duo') } }), { median = 3000 })
    T.no(p.falling_behind)
end

function S.bonus_by_phase(T)
    local F, PL, DB = env()
    local early = PL.analyse(F.state({ ante = 1 }))
    local late = PL.analyse(F.state({ ante = 7, jokers = { F.joker('j_joker') } }))
    T.ok(PL.joker_bonus(DB.get('j_joker'), early) > 0, 'first scoring jokers: welcome early')
    T.ok(PL.joker_bonus(DB.get('j_joker'), late) < 0, '+Mult outgrown late')
    T.ok(PL.joker_bonus(DB.get('j_duo'), late) > PL.joker_bonus(DB.get('j_duo'), early), 'multipliers matter more and more')
    T.ok(PL.joker_bonus(DB.get('j_golden'), early) > PL.joker_bonus(DB.get('j_golden'), late), 'economy early, not late')
end

function S.needed_multiplier_not_traded_for_chips(T)
    -- ante 3: one x Mult due at ante 4; Baron is the only one: replacing it by Crafty Joker
    -- (+80 chips) costs the multiplier of the next ante
    local F, PL, DB = env()
    local p = PL.analyse(F.state({ ante = 3, jokers = { F.joker('j_baron'), F.joker('j_joker') } }))
    T.eq(p.xmult, 1); T.eq(p.next_target, 1)
    local pen, why = PL.replace_penalty(DB.get('j_baron'), DB.get('j_crafty'), p)
    T.ok(pen > 0 and why, 'penalty')
    T.eq(PL.replace_penalty(DB.get('j_baron'), DB.get('j_duo'), p), 0, 'x Mult for x Mult: no penalty')
    T.eq(PL.replace_penalty(DB.get('j_joker'), DB.get('j_crafty'), p), 0, '+Mult replaced: no penalty')
end

function S.plan_shown_in_the_shop(T)
    local F, PL = env()
    local FS = BSCopilot.require('ui/format_strategy')
    local s = F.state({ ante = 3, levels = { Flush = 4 }, jokers = { F.joker('j_joker') } })
    s.hands.Flush.played = 6
    local lines = FS.plan_lines(PL.analyse(s), s)
    local txt = ''
    for _, l in ipairs(lines) do for _, sg in ipairs(l) do txt = txt .. sg.t end txt = txt .. '\n' end
    T.ok(txt:find('Couleur (niv. 4)', 1, true) and txt:find('×Mult 0 / 0', 1, true) and txt:find('multiplicateur', 1, true), txt)
end

return S
