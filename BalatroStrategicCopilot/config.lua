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
