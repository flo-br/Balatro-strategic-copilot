-- Balatro Strategic Copilot - default configuration.
-- Steamodded saves the user's changes in %AppData%/Balatro/config/BalatroStrategicCopilot.jkr
return {
    enabled = true,
    lang = 'fr',                 -- 'fr' (default) or 'en'
    keys = {
        panel = 'c',             -- open/close the strategic panel
        detail = 'v',            -- show/hide alternatives and details
        badges = 'b',            -- show/hide badges over cards
    },
    ui = {
        anchor = 'right',        -- 'right' or 'left'
        scale = 1.0,
        show_badges = true,
        show_compact = true,     -- small summary box when the panel is closed
        panel_open = false,
        detail = true,
        use_game_font = true,    -- false: LÖVE default font (crisper at small sizes)
    },
    alerts = {
        enabled = true,
        danger_threshold = 0.5,  -- warn when P(beat next blind) is below this
        great_buy_note = 80,     -- alert for shop options rated at least this
        joker_order_gain = 0.10, -- alert when reordering jokers gains at least 10 %
        cooldown = 25,           -- seconds before the same alert can be shown again
        duration = 5,            -- seconds an alert stays on screen
    },
    thresholds = {
        prob_good = 0.80, prob_mid = 0.50,
        note_good = 70, note_mid = 45,
    },
    compute = {
        budget_ms = 4,           -- analysis time per frame (milliseconds)
        rollouts = 64,           -- simulated rounds per candidate action
        max_branches = 48,       -- exact enumeration limit of random events per hand
        samples = 160,           -- Monte-Carlo samples when enumeration is too large
        poll_interval = 0.15,    -- seconds between state-change checks
        shop_samples = 120,      -- simulated hands to estimate build power
    },
    advice = {                   -- the "À FAIRE" step (engine/advice.lua)
        buy_note = 56,           -- buy / take an item from this strategic score (/100, 50 = neutral)
        sell_note = 60,          -- sell a joker for money from this score...
        sell_max_contribution = 0.03, -- ...and only if it brings at most 3 % of the score
        order_min_gain = 0.01,   -- show the joker order numbers when the right order scores >= 1 % more
        luchador_below = 0.80,   -- advise selling Luchador against a boss below 80 % win chance
        -- money discipline inspired by top players, applied only while the next blinds are safe
        booster_note = 52,       -- boosters are bought from this score (top players buy them very often)
        strong_note = 75,        -- an item this strong is bought even if it breaks the savings
        save_from_ante = 2,      -- from this ante, keep the interest cap ($25) and spend only the excess
        interest_weight = 3,     -- before that, each $ of interest lost raises the required score by 3
        safe_next = 0.85,        -- "safe" = next blind won with at least 85 % ...
        safe_boss = 0.70,        -- ... and the boss with at least 70 %
        reroll_once = true,      -- nothing worth buying: one reroll per shop before leaving
        reroll_once_max_loss = 1, -- ... if it costs at most 1 $ of interest (before the savings ante)
        rich_reserve = 10,       -- money above the interest cap + this is rerolled to fill the plan's gaps (xMult, power)
        replace_note = 60,       -- replacing a joker (sell + buy) needs a clear gain: no churn
        danger_rerolls = 2,      -- at most this many rerolls per shop when the next blinds are in danger
        excess_note = 54,        -- with money still above the cap after buying, any real improvement is bought
        excess_reserve = 5,      -- ... keeping this much above the cap
        idle_reserve = 20,       -- money above the cap + this is rerolled even without a gap (idle money)
        first_jokers = 3,        -- antes 1-2: the first 3 jokers fill empty slots from excess_note, savings or not
    },
    learning = {
        enabled = true,
        max_runs_kept = 300,     -- raw run logs kept on disk (summaries are kept forever)
        min_samples_calibration = 30,
    },
    log = {
        level = 'info',          -- off, error, warn, info, debug, trace
        file = true,
        max_file_kb = 512,
    },
}
