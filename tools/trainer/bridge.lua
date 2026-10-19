-- Balatro Strategic Copilot - tools/trainer/bridge.lua
-- Simulated run summary (run.lua) -> the recorder's run format (learning/recorder.lua), so the
-- mod's own post-run review and self-adjustment can be applied to simulated runs.
local H = BSCopilot.require('model/hands')
local B = {}

function B.to_run(r)
    local run = { id = 'sim_' .. tostring(r.seed), won = r.won, final_ante = r.ante, blinds = {}, hands = {}, decisions = {},
        power = r.power or {}, builds = r.builds or {}, economy = {}, end_reason = r.won and 'won' or 'lost' }
    for _, h in ipairs(r.history or {}) do
        run.blinds[#run.blinds + 1] = { ante = h.ante, key = h.key, chips = h.required, boss = h.slot == 'Boss', p_pred = h.p_pred,
            cleared = h.won, score = h.scored }
        run.economy[#run.economy + 1] = { ante = h.ante, dollars = h.dollars }
        if not h.won then run.lost_to = h.key end
    end
    for _, d in ipairs(r.decisions or {}) do
        if d.kind == 'use' and d.key and H.PLANETS[d.key] then run.decisions[#run.decisions + 1] = { kind = 'using_consumeable', key = d.key, ante = d.ante } end
        if d.kind == 'skip' then run.decisions[#run.decisions + 1] = { kind = 'skip_blind', ante = d.ante, followed = true } end
    end
    return run
end

return B
