-- Balatro Strategic Copilot - game/config_ui.lua
-- Steamodded configuration tab (mod.config_tab), built with the vanilla UI helpers used by
-- Steamodded itself (create_toggle, UIBox_button, G.UIT nodes; see docs/AUDIT.md).
-- Steamodded saves mod.config when the mods menu is closed.

local BSC = BSCopilot
local L = BSC.require('core/log')
local I = BSC.require('core/i18n')

local CU = {}

local function text_row(text, scale, colour)
    local G = rawget(_G, 'G')
    return { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
        { n = G.UIT.T, config = { text = text, scale = scale or 0.4, colour = colour or G.C.WHITE, shadow = true } },
    } }
end

function CU.attach(mod)
    if type(mod) ~= 'table' then return end
    local G = rawget(_G, 'G')
    if not (G and G.FUNCS) then return end
    local cfg = BSC.config

    G.FUNCS.bsc_export = function(e)
        local ok, res = pcall(function() return BSC.learning_runtime and BSC.learning_runtime.export() end)
        L.info('config', 'export: %s', tostring(ok and res or res))
        if BSC.controller then BSC.controller.alert('export', ok and res and ('Export : ' .. tostring(res)) or 'Export impossible', ok and 'good' or 'bad') end
    end
    G.FUNCS.bsc_import = function(e)
        local ok, res = pcall(function() return BSC.learning_runtime and BSC.learning_runtime.import() end)
        if BSC.controller then BSC.controller.alert('import', ok and ('Import : ' .. tostring(res)) or 'Import impossible', ok and 'good' or 'bad') end
    end
    CU.reset_armed = 0
    G.FUNCS.bsc_reset = function(e)
        local now = os.time()
        if now - (CU.reset_armed or 0) > 5 then
            CU.reset_armed = now
            if BSC.controller then BSC.controller.alert('reset_confirm', 'Cliquez à nouveau pour confirmer la réinitialisation', 'mid') end
            return
        end
        CU.reset_armed = 0
        local ok = pcall(function() return BSC.learning_runtime and BSC.learning_runtime.reset() end)
        if BSC.controller then BSC.controller.alert('reset', ok and 'Apprentissage réinitialisé (sauvegarde conservée)' or 'Réinitialisation impossible', ok and 'good' or 'bad') end
    end

    mod.config_tab = function()
        local nodes = {
            text_row('Balatro Strategic Copilot ' .. tostring(BSC.VERSION), 0.5, G.C.GOLD),
            create_toggle({ label = 'Panneau ouvert au démarrage', ref_table = cfg.ui, ref_value = 'panel_open' }),
            create_toggle({ label = 'Badges sur les cartes', ref_table = cfg.ui, ref_value = 'show_badges' }),
            create_toggle({ label = 'Résumé compact', ref_table = cfg.ui, ref_value = 'show_compact' }),
            create_toggle({ label = 'Alertes', ref_table = cfg.alerts, ref_value = 'enabled' }),
            create_toggle({ label = 'Apprentissage entre les parties', ref_table = cfg.learning, ref_value = 'enabled' }),
            text_row('Touches : panneau [' .. (cfg.keys.panel or 'c'):upper() .. '], détail [' .. (cfg.keys.detail or 'v'):upper()
                .. '], badges [' .. (cfg.keys.badges or 'b'):upper() .. '] (modifiables dans config)', 0.3, G.C.UI and G.C.UI.TEXT_LIGHT),
            UIBox_button({ button = 'bsc_export', label = { 'Exporter les données' }, minw = 5, minh = 0.6, scale = 0.4 }),
            UIBox_button({ button = 'bsc_import', label = { 'Importer (dossier BSC/import)' }, minw = 5, minh = 0.6, scale = 0.4 }),
            UIBox_button({ button = 'bsc_reset', label = { 'Réinitialiser l\'apprentissage' }, minw = 5, minh = 0.6, scale = 0.4, colour = G.C.RED }),
        }
        return { n = G.UIT.ROOT, config = { align = 'cm', padding = 0.1, r = 0.1, colour = G.C.BLACK, minw = 8 }, nodes = {
            { n = G.UIT.C, config = { align = 'cm', padding = 0.05 }, nodes = nodes },
        } }
    end
end

return CU
