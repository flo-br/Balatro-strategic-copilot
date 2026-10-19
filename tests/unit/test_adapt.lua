local T = ...
local S = {}

local function env()
    local AD = BSCopilot.require('learning/adapt')
    local LE = BSCopilot.require('learning/learning')
    return AD, LE
end

local function review(...)
    local causes = {}
    for i, k in ipairs({ ... }) do causes[i] = { key = k, text = k } end
    return { causes = causes, result = 'loss' }
end

function S.losses_move_settings_one_bounded_step(T)
    local AD, LE = env()
    local prof = LE.new_profile(0)
    -- one loss is not a pattern: nothing moves
    local ch = AD.update(prof, review('idle_money', 'deficit'), { id = 'r1', won = false })
    T.eq(#ch, 0, 'a single loss changes nothing')
    -- the same cause in a second loss: one step on its settings
    ch = AD.update(prof, review('idle_money', 'deficit', 'power_drop'), { id = 'r2', won = false })
    local d = AD.deltas(prof)
    T.eq(d.excess_note, -2); T.eq(d.excess_reserve, -2); T.eq(d.idle_reserve, -4)
    T.eq(#ch, 3, 'three settings changed')
    T.eq(ch[1].causes[1], 'idle_money')
    -- "a hand below the blind" and "power drop" are in every loss: they move nothing
    T.eq(d.safe_next, nil); T.eq(d.buy_note, nil); T.eq(d.save_from_ante, nil)
    -- the same run is never counted twice
    AD.update(prof, review('idle_money'), { id = 'r2', won = false })
    T.eq(AD.deltas(prof).excess_note, -2)
    -- bounded
    for i = 3, 20 do AD.update(prof, review('idle_money'), { id = 'r' .. i, won = false }) end
    T.eq(AD.deltas(prof).excess_note, -8, 'never below the bound')
    T.eq(#prof.adapt.history, AD.HISTORY_KEPT)
end

function S.causes_also_seen_in_wins_move_nothing(T)
    -- idle money in the wins as often as in the losses: not what loses the runs
    local AD, LE = env()
    local prof = LE.new_profile(0)
    for i = 1, 3 do AD.update(prof, review('idle_money'), { id = 'w' .. i, won = true }) end
    for i = 1, 3 do AD.update(prof, review('idle_money'), { id = 'l' .. i, won = false }) end
    T.eq(AD.deltas(prof).excess_note, nil, 'not discriminating: no change')
    -- few jokers only in losses: it moves
    for i = 4, 5 do AD.update(prof, review('few_jokers'), { id = 'l' .. i, won = false }) end
    T.eq(AD.deltas(prof).first_jokers, 1)
end

function S.a_win_moves_back_toward_base(T)
    local AD, LE = env()
    local prof = LE.new_profile(0)
    AD.update(prof, review('few_jokers'), { id = 'a1', won = false })
    AD.update(prof, review('few_jokers'), { id = 'a2', won = false })
    T.eq(AD.deltas(prof).first_jokers, 1)
    local ch = AD.update(prof, { causes = {}, result = 'win' }, { id = 'b', won = true })
    T.eq(AD.deltas(prof).first_jokers, 0)
    T.ok(ch[1] and ch[1].won, 'shown as a return toward base')
end

function S.adjustments_apply_to_the_advice_and_skips(T)
    local AD, LE = env()
    local A = BSCopilot.require('engine/advice')
    local cfg = { advice = { excess_note = 54 }, adapt_deltas = { excess_note = -4, first_jokers = 1, skip_margin = 2 } }
    local st = A.settings(cfg)
    T.eq(st.excess_note, 50)
    T.eq(st.first_jokers, 4)
    T.eq(st.buy_note, 56, 'untouched settings keep config.lua')
    local SK = BSCopilot.require('engine/skip')
    local F = dofile(T.REPO_ROOT .. '/tests/fixtures/states.lua')
    local s = F.state({ dollars = 4 })
    s.blind_tags = { Small = 'tag_investment', Big = 'tag_rare' }
    local r = SK.evaluate(s, { current = { slot = 'Small', reward = 3, chips = 300 }, p_following = 0.97, p_boss = 0.95,
        median = 200, plan = { gaps = {} } }, cfg)
    T.ok(r.margin ~= nil)
    -- the review shows what changed and why
    local RV = BSCopilot.require('learning/review')
    local txt = RV.adapt_text({ key = 'excess_note', from = 0, to = -2, causes = { 'idle_money' } })
    T.ok(txt:find('argent dormant', 1, true) and txt:find('-2', 1, true), txt)
end

return S
