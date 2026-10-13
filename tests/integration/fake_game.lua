-- Fake Balatro + Steamodded + LÖVE environment for integration tests.
-- It reproduces the structures the mod reads (as verified in the Steamodded sources and the
-- vanilla code they quote). It is NOT the real game: see docs/TESTS.md for what remains untested.
local FG = {}

local sort_id = 0
local function next_id() sort_id = sort_id + 1; return sort_id end

local RANKS = {
    ['2'] = { 2, 2, 0 }, ['3'] = { 3, 3, 0 }, ['4'] = { 4, 4, 0 }, ['5'] = { 5, 5, 0 }, ['6'] = { 6, 6, 0 },
    ['7'] = { 7, 7, 0 }, ['8'] = { 8, 8, 0 }, ['9'] = { 9, 9, 0 }, ['10'] = { 10, 10, 0 },
    Jack = { 11, 10, 0.1 }, Queen = { 12, 10, 0.2 }, King = { 13, 10, 0.3 }, Ace = { 14, 11, 0.4 },
}
local SUITN = { Diamonds = 0.01, Clubs = 0.02, Hearts = 0.03, Spades = 0.04 }
local SHORT = { T = '10', J = 'Jack', Q = 'Queen', K = 'King', A = 'Ace' }
local SUITS = { S = 'Spades', H = 'Hearts', C = 'Clubs', D = 'Diamonds' }

local ENH = {
    m_bonus = { bonus = 30 }, m_mult = { mult = 4 }, m_glass = { x_mult = 2 }, m_steel = { h_x_mult = 1.5 },
    m_stone = { bonus = 50 }, m_gold = { h_dollars = 3 }, m_lucky = { mult = 20, p_dollars = 20 }, m_wild = {},
}

function FG.card(code, opts)
    opts = opts or {}
    local rs, ss = code:match('^(%w-)(%a)$')
    local rank = SHORT[rs] or rs
    local suit = SUITS[ss]
    local r = RANKS[rank]
    local x = opts.x or 0
    local c = {
        sort_id = next_id(),
        base = { value = rank, suit = suit, id = r[1], nominal = r[2], face_nominal = r[3], suit_nominal = SUITN[suit] },
        ability = { set = opts.enh and 'Enhanced' or 'Default', bonus = 0, mult = 0, x_mult = 1, h_x_mult = 0, h_mult = 0,
            p_dollars = 0, h_dollars = 0, perma_bonus = 0, effect = '' },
        config = { center = { key = opts.enh or 'c_base', set = opts.enh and 'Enhanced' or 'Default' } },
        seal = opts.seal, edition = opts.edition, debuff = opts.debuff or false, facing = opts.facing or 'front',
        T = { x = x, y = 5, w = 0.9, h = 1.2 }, highlighted = false, cost = opts.cost or 1, sell_cost = 1,
    }
    if opts.enh and ENH[opts.enh] then for k, v in pairs(ENH[opts.enh]) do c.ability[k] = v end end
    c.VT = { x = c.T.x, y = c.T.y, w = c.T.w, h = c.T.h }
    return c
end

function FG.joker(key, name, ability, opts)
    opts = opts or {}
    local ab = { set = 'Joker', name = name, extra = nil, mult = 0, x_mult = 1 }
    for k, v in pairs(ability or {}) do ab[k] = v end
    return {
        sort_id = next_id(), ability = ab,
        config = { center = { key = key, rarity = opts.rarity or 1, blueprint_compat = opts.bp ~= false, set = 'Joker' } },
        edition = opts.edition, debuff = opts.debuff or false, facing = 'front', sell_cost = opts.sell_cost or 2, cost = opts.cost or 4,
        T = { x = 2, y = 1, w = 0.9, h = 1.2 }, VT = { x = 2, y = 1, w = 0.9, h = 1.2 },
    }
end

local function area(cards, limit)
    return { cards = cards or {}, config = { card_limit = limit or 8 }, highlighted = {} }
end

function FG.install(opts)
    opts = opts or {}
    sort_id = 0
    local calls = { draw = {}, keybinds = {}, logs = {} }
    FG.calls = calls

    -- LÖVE -------------------------------------------------------------------------------------
    local mem = {}
    local function font(size)
        return {
            size = size,
            getWidth = function(self, t) return #tostring(t) * size * 0.5 end,
            getHeight = function(self) return size end,
            hasGlyphs = function(self, t) return opts.glyphs == true end,
        }
    end
    love = {
        timer = { getTime = function() return os.clock() end },
        graphics = {
            getDimensions = function() return 1920, 1080 end,
            newFont = function(a, b) return font(type(a) == 'number' and a or b or 12) end,
            push = function(m) calls.draw[#calls.draw + 1] = 'push' end,
            pop = function() calls.draw[#calls.draw + 1] = 'pop' end,
            origin = function() end, setFont = function() end, setColor = function() end, setLineWidth = function() end,
            setScissor = function() end,
            rectangle = function(mode, x, y, w, h) calls.draw[#calls.draw + 1] = 'rect' end,
            print = function(t, x, y) calls.draw[#calls.draw + 1] = 'print:' .. tostring(t) end,
        },
        filesystem = {
            getInfo = function(p)
                if mem[p] then return { type = 'file', size = #mem[p] } end
                if mem['dir:' .. p] then return { type = 'directory' } end
                return nil
            end,
            read = function(p) return mem[p] end,
            write = function(p, d) mem[p] = d; return true end,
            append = function(p, d) mem[p] = (mem[p] or '') .. d; return true end,
            createDirectory = function(p) mem['dir:' .. p] = true; return true end,
            remove = function(p) mem[p] = nil; return true end,
            getDirectoryItems = function(dir)
                local out = {}
                for k in pairs(mem) do
                    if k:sub(1, #dir + 1) == dir .. '/' and not k:find('^dir:') then out[#out + 1] = k:sub(#dir + 2) end
                end
                return out
            end,
            getSaveDirectory = function() return 'memory' end,
        },
    }
    FG.mem = mem

    -- logging functions provided by Steamodded
    for _, n in ipairs({ 'sendDebugMessage', 'sendInfoMessage', 'sendWarnMessage', 'sendErrorMessage', 'sendTraceMessage' }) do
        _G[n] = function(msg, logger) calls.logs[#calls.logs + 1] = n .. ': ' .. tostring(msg) end
    end

    -- Game class
    Game = {}
    Game.__index = Game
    function Game:update(dt) calls.game_update = (calls.game_update or 0) + 1 end
    function Game:draw() calls.game_draw = (calls.game_draw or 0) + 1 end

    -- G ----------------------------------------------------------------------------------------
    local S = { SELECTING_HAND = 1, HAND_PLAYED = 2, DRAW_TO_HAND = 3, GAME_OVER = 4, SHOP = 5, PLAY_TAROT = 6,
        BLIND_SELECT = 7, ROUND_EVAL = 8, TAROT_PACK = 9, PLANET_PACK = 10, MENU = 11, SPLASH = 13,
        SPECTRAL_PACK = 15, STANDARD_PACK = 17, BUFFOON_PACK = 18, NEW_ROUND = 19, SMODS_BOOSTER_OPENED = 999 }
    local hands = {}
    local base = {
        ['Flush Five'] = { 160, 16, 50, 3 }, ['Flush House'] = { 140, 14, 40, 4 }, ['Five of a Kind'] = { 120, 12, 35, 3 },
        ['Straight Flush'] = { 100, 8, 40, 4 }, ['Four of a Kind'] = { 60, 7, 30, 3 }, ['Full House'] = { 40, 4, 25, 2 },
        ['Flush'] = { 35, 4, 15, 2 }, ['Straight'] = { 30, 4, 30, 3 }, ['Three of a Kind'] = { 30, 3, 20, 2 },
        ['Two Pair'] = { 20, 2, 20, 1 }, ['Pair'] = { 10, 2, 15, 1 }, ['High Card'] = { 5, 1, 10, 1 },
    }
    for name, v in pairs(base) do
        hands[name] = { level = 1, chips = v[1], mult = v[2], s_chips = v[1], s_mult = v[2], l_chips = v[3], l_mult = v[4],
            played = 0, played_this_round = 0, visible = true }
    end
    local hand_cards = {}
    for i, code in ipairs(opts.hand or { 'Ah', 'Ad', '7c', '9s', '2h', 'Kh', '5d', '3c' }) do
        hand_cards[i] = FG.card(code, { x = i })
    end
    local deck_cards = {}
    for _, code in ipairs(opts.deck or { '2s', '3s', '4s', '5s', '6s', '7s', '8s', '9h', 'Th', 'Jh', 'Qh', 'Kd', 'Ac', 'Ks', 'Qc' }) do
        deck_cards[#deck_cards + 1] = FG.card(code)
    end
    local playing = {}
    for _, c in ipairs(hand_cards) do playing[#playing + 1] = c end
    for _, c in ipairs(deck_cards) do playing[#playing + 1] = c end

    G = {
        STATES = S, STATE = opts.state or S.SELECTING_HAND, STAGES = { MAIN_MENU = 1, RUN = 2 }, STAGE = 2,
        TILESCALE = 1, TILESIZE = 20, ROOM = { T = { x = 1, y = 1, w = 20, h = 11 } },
        LANG = { font = { file = 'resources/fonts/m6x11plus.ttf' } },
        P_CENTERS = { v_observatory = { config = { extra = 1.5 } } },
        P_BLINDS = { bl_small = { name = 'Small Blind', mult = 1, dollars = 3 }, bl_big = { name = 'Big Blind', mult = 1.5, dollars = 4 },
            bl_hook = { name = 'The Hook', mult = 2, boss = { min = 1 }, dollars = 5 } },
        FUNCS = {},
        C = { WHITE = { 1, 1, 1, 1 }, BLACK = { 0, 0, 0, 1 }, GOLD = { 1, 0.8, 0, 1 }, RED = { 1, 0, 0, 1 }, UI = { TEXT_LIGHT = { 1, 1, 1, 1 } } },
        UIT = { ROOT = 0, R = 1, C = 2, T = 3, O = 4 },
        GAME = {
            round_resets = { ante = opts.ante or 1, blind_choices = { Small = 'bl_small', Big = 'bl_big', Boss = 'bl_hook' },
                blind_states = { Small = 'Current', Big = 'Upcoming', Boss = 'Upcoming' }, hands = 4, discards = 3, reroll_cost = 5 },
            round = 1, win_ante = 8, stake = 1, won = false, hands_played = 0, skips = 0, dollars = opts.dollars or 4,
            interest_cap = 25, interest_amount = 1, modifiers = {}, starting_params = { ante_scaling = 1 },
            selected_back = { name = 'Red Deck', effect = { center = { key = 'b_red' } } },
            pseudorandom = { seed = 'TESTSEED' }, chips = opts.chips or 0,
            blind = { name = 'Small Blind', chips = opts.required or 300, boss = false, disabled = false, config = { blind = { key = 'bl_small' } } },
            current_round = { hands_left = opts.hands_left or 4, discards_left = opts.discards_left or 3, hands_played = 0, discards_used = 0,
                reroll_cost = 5, free_rerolls = 0, ancient_card = { suit = 'Spades' }, idol_card = { id = 14, suit = 'Hearts', rank = 'Ace' },
                castle_card = { suit = 'Clubs' }, mail_card = { id = 5, rank = '5' }, most_played_poker_hand = 'High Card' },
            hands = hands, used_vouchers = {}, probabilities = { normal = 1 }, consumeable_usage_tally = { tarot = 0, planet = 0 },
            starting_deck_size = 52, joker_rate = 20, tarot_rate = 4, planet_rate = 4, spectral_rate = 0, playing_card_rate = 0,
        },
        hand = area(hand_cards, 8),
        deck = area(deck_cards, 52),
        jokers = area(opts.jokers or {}, 5),
        consumeables = area({}, 2),
        playing_cards = playing,
    }
    if opts.shop then
        G.shop_jokers = area(opts.shop, 2)
        G.shop_vouchers = area(opts.shop_vouchers or {}, 1)
        G.shop_booster = area(opts.shop_boosters or {}, 2)
    end

    -- Steamodded ------------------------------------------------------------------------------
    local mod_root = opts.mod_root
    local cfg = dofile(mod_root .. '/config.lua')
    SMODS = {
        Mods = {},
        current_mod = { id = 'BalatroStrategicCopilot', path = mod_root .. '/', config = cfg, can_load = true },
        load_file = function(path, id)
            local chunk, err = loadfile(mod_root .. '/' .. path)
            return chunk, err
        end,
    }
    SMODS.Mods.BalatroStrategicCopilot = SMODS.current_mod
    SMODS.Keybind = setmetatable({}, { __call = function(_, t) calls.keybinds[#calls.keybinds + 1] = t; return t end })
    MODDED_VERSION = '26.1002.0'
    VERSION = '1.0.1o-FULL'
    -- vanilla UI helpers used by the config tab
    create_toggle = function(t) return { toggle = t } end
    UIBox_button = function(t) return { button = t } end
    get_blind_amount = function(ante) return ({ 300, 800, 2000, 5000, 11000, 20000, 35000, 50000 })[ante] or 100 end
    return G
end

function FG.uninstall()
    G, SMODS, Game, love, BSCopilot = nil, nil, nil, nil, nil
    create_toggle, UIBox_button, get_blind_amount, MODDED_VERSION, VERSION = nil, nil, nil, nil, nil
end

-- Simulate n frames of the game loop.
function FG.frames(n, dt)
    for _ = 1, n do
        Game.update(G, dt or 0.05)
    end
end

return FG
