-- Balatro Strategic Copilot - amorce du MODE AUTONOME (sans Lovely ni Steamodded)
-- ==========================================================================================
-- Emplacement : %AppData%\Balatro\main.lua   (le dossier de sauvegarde de Balatro)
--
-- Pourquoi ça marche : Balatro tourne sur le moteur LÖVE 11. Juste avant de lire le main.lua
-- du jeu, LÖVE place le dossier de sauvegarde EN PREMIER dans son ordre de recherche
-- (boot.lua de LÖVE 11.3 à 11.5 : setIdentity(..., appendidentity) avec appendidentity = false
-- par défaut). Ce fichier est donc lu à la place de celui qui est dans Balatro.exe.
--
-- Ce qu'il fait : 1) il exécute le main.lua D'ORIGINE du jeu, inchangé (lu dans Balatro.exe) ;
-- 2) à la première image du jeu, il démarre le copilote depuis Mods\BalatroStrategicCopilot.
-- Aucun fichier du jeu n'est modifié, rien n'est téléchargé, aucune DLL, aucun script Windows.
-- Trace de chaque étape : %AppData%\Balatro\BSC\amorce.log
--
-- Désinstaller : supprimer CE fichier (le jeu redevient exactement l'original).
-- Avec Lovely + Steamodded, ce fichier est inutile : il laisse alors Steamodded gérer le copilote.
-- ==========================================================================================

do
    local MARK = 'BSCOPILOT_AMORCE_AUTONOME'
    local fs = love.filesystem
    local MOD_DIR = 'Mods/BalatroStrategicCopilot'

    local function note(msg)
        pcall(function()
            fs.createDirectory('BSC')
            local info = fs.getInfo('BSC/amorce.log')
            if info and info.size and info.size > 64 * 1024 then fs.write('BSC/amorce.log', '') end
            fs.append('BSC/amorce.log', os.date('%Y-%m-%d %H:%M:%S') .. '  ' .. tostring(msg) .. '\r\n')
        end)
    end

    note(('amorce lue (LÖVE %s, dossier %s)'):format(table.concat({ love.getVersion() }, '.', 1, 3), tostring(fs.getSaveDirectory())))

    -- 1. main.lua d'origine : le dossier de sauvegarde passe un instant APRÈS le jeu, pour que
    --    'main.lua' désigne le fichier de Balatro.exe, puis l'ordre normal est rétabli.
    local identity = fs.getIdentity()
    fs.setIdentity(identity, true)
    local source = fs.read('main.lua')
    fs.setIdentity(identity, false)
    if type(source) ~= 'string' or source:find(MARK, 1, true) then
        note('ERREUR : main.lua d\'origine introuvable')
        error('Balatro Strategic Copilot : le main.lua d\'origine du jeu est introuvable.\n'
            .. 'Supprimez %AppData%\\Balatro\\main.lua pour retrouver le jeu normal.')
    end
    -- même nom de morceau que LÖVE ('@main.lua') : si Lovely est installé, il le modifie comme d'habitude
    local original = assert(loadstring(source, '@main.lua'))
    original()
    note('main.lua d\'origine exécuté')

    -- 2. démarrage du copilote à la première image (le jeu est alors entièrement chargé)
    local boot_error = nil

    local function boot_copilot()
        local SM = rawget(_G, 'SMODS')
        if type(SM) == 'table' and type(SM.Mods) == 'table' and SM.Mods.BalatroStrategicCopilot then
            note('Steamodded gère déjà le copilote : mode autonome non utilisé')
            return
        end
        if rawget(_G, 'BSCopilot') and BSCopilot.status then
            note('copilote déjà démarré')
            return
        end
        if not fs.getInfo(MOD_DIR .. '/main.lua') then
            boot_error = 'dossier introuvable : %AppData%\\Balatro\\Mods\\BalatroStrategicCopilot\\main.lua'
            note('ERREUR : ' .. boot_error)
            return
        end
        BSCopilot = { root_lfs = MOD_DIR, standalone = true }
        local chunk, err = fs.load(MOD_DIR .. '/main.lua')
        if not chunk then
            boot_error = tostring(err)
            note('ERREUR au chargement : ' .. boot_error)
            return
        end
        local ok, e = pcall(chunk)
        if not ok then
            boot_error = tostring(e)
            note('ERREUR au démarrage : ' .. boot_error)
            return
        end
        local st = BSCopilot.status
        note('copilote ' .. tostring(BSCopilot.VERSION) .. ' : ' .. tostring(st and st.text or '?'))
    end

    local started = false
    local update_ref = love.update
    if type(update_ref) == 'function' then
        love.update = function(...)
            update_ref(...)
            if not started then
                started = true
                local ok, e = pcall(boot_copilot)
                if not ok then boot_error = tostring(e); note('ERREUR : ' .. boot_error) end
            end
        end
    else
        note('ERREUR : love.update absent après le main.lua d\'origine')
    end

    -- bandeau rouge si le copilote n'a pas pu démarrer (le jeu, lui, continue normalement)
    local draw_ref = love.draw
    if type(draw_ref) == 'function' then
        love.draw = function(...)
            draw_ref(...)
            if boot_error then
                pcall(function()
                    local g = love.graphics
                    local text = 'Balatro Strategic Copilot (mode autonome) : ' .. boot_error
                        .. '\nDétails : %AppData%\\Balatro\\BSC\\amorce.log'
                    g.push('all')
                    g.origin()
                    local W = g.getDimensions()
                    g.setColor(0.55, 0.10, 0.10, 0.95)
                    g.rectangle('fill', 10, 8, W - 20, 52, 6, 6)
                    g.setColor(1, 1, 1, 1)
                    g.printf(text, 20, 14, W - 40)
                    g.pop()
                end)
            end
        end
    end
end

-- Rien après cette ligne ne doit s'exécuter : si Lovely est installé, il ajoute à ce fichier le
-- même code qu'au main.lua d'origine, qui l'a déjà exécuté ci-dessus.
do return end
