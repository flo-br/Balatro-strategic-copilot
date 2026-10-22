-- Balatro Strategic Copilot - tools/synergies_doc.lua
-- Writes docs/SYNERGIES.md from the synergy lists of the mod (model/builds_db.lua and
-- model/synergies_db.lua, merged as engine/builds.lua merges them).
-- Usage (repository root):  luajit tools/synergies_doc.lua docs/SYNERGIES.md
-- tests/unit/test_synergies.lua checks that docs/SYNERGIES.md is up to date.

local mode = ...
local DOC = {}

local TIER_LABEL = { S = 'S (gagne la partie)', A = 'A (forte)', B = 'B (bonne)', C = 'C (mineure)', X = 'X (anti-synergie)' }
local TIER_ORDER = { S = 1, A = 2, B = 3, C = 4, X = 5 }

function DOC.render()
    local BD = BSCopilot.require('engine/builds')
    local DB = BSCopilot.require('model/jokers_db')
    local function name(k) local d = DB.get(k); return (d and d.name) or BD.item_name(k) end
    local out = {}
    local function w(s) out[#out + 1] = s or '' end

    -- per joker: its partners (both directions) and its items
    local by = {}
    local function push(k, e) by[k] = by[k] or {}; table.insert(by[k], e) end
    -- counted in the note, or shown only (the score engine measures it already)
    local function counted_pair(p)
        if p.list == 'builds' then return true end
        return BD.LIST_SCALE ~= 0 and (p.future or BD.STATIC_SCALE ~= 0)
    end
    local function counted_item(e) return (BD.ITEM_SCALE or 1) ~= 0 and (e.future or BD.STATIC_SCALE ~= 0) end
    local n_shown = 0
    for _, p in ipairs(BD.PAIRS) do
        local c = counted_pair(p)
        if not c then n_shown = n_shown + 1 end
        push(p.a, { tier = p.tier, other = name(p.b), why = p.why, shown = not c })
        push(p.b, { tier = p.tier, other = name(p.a), why = p.why, shown = not c })
    end
    for k, list in pairs(BD.ITEMS_OF_JOKER) do
        for _, e in ipairs(list) do
            local c = counted_item(e)
            if not c then n_shown = n_shown + 1 end
            push(k, { tier = e.tier, other = BD.item_name(e.item), why = e.why, item = true, shown = not c })
        end
    end
    local keys = DB.all_keys()
    table.sort(keys, function(a, b) return name(a):lower() < name(b):lower() end)
    local n_items = 0
    for _, list in pairs(BD.ITEMS_OF_JOKER) do n_items = n_items + #list end

    w('# Synergies des jokers')
    w()
    w('Fichier généré par `luajit tools/synergies_doc.lua docs/SYNERGIES.md` à partir de')
    w('`BalatroStrategicCopilot/src/model/builds_db.lua` et `BalatroStrategicCopilot/src/model/synergies_db.lua`')
    w('(ne pas modifier à la main : modifier les listes puis relancer l\'outil).')
    w()
    w(string.format('**%d paires joker + joker, %d synergies joker + carte / bon / paquet, %d builds**, et des règles', #BD.PAIRS, n_items, #BD.BUILDS))
    w('générales pour ce qu\'aucune liste ne peut énumérer. Tous les jokers du jeu de base (' .. #keys .. ') y figurent.')
    w()
    w('## Comment le copilote s\'en sert')
    w()
    w('- Le moteur de score **mesure** ce que vos jokers font ensemble maintenant (Blueprint + The Duo, Jolly + Sly,')
    w('  The Chariot avec Steel Joker : l\'amélioration est simulée). Une synergie ne s\'ajoute à la note que pour ce que')
    w('  cette mesure ne voit pas encore : une pièce qui **grandit**, rapporte de l\'argent, crée des cartes ou change le')
    w('  deck plus tard (Hologram, Constellation, Yorick, Bull…), ou un objet dont l\'effet n\'est pas simulé (Cryptid,')
    w('  Death, Observatory…). Les autres sont **affichées** (raisons des notes, « Synergies à chercher », cette liste)')
    w('  sans être comptées deux fois ; elles sont marquées ° ci-dessous.')
    w('- **Comptée**, une synergie ajoute au « potentiel » d\'un joker en boutique ou dans un paquet : S +0,4, A +0,28,')
    w('  B +0,16, C +0,07, X −0,25, total borné entre −0,5 et +0,6, ×0,7 aux antes 1-2 (les pros ne forcent pas encore')
    w('  un build) ; pour une carte, un bon ou un paquet, entre −0,4 et +0,5. Les bons achetés et les cartes tenues')
    w('  comptent aussi pour un joker (Perkeo quand Observatory est acheté).')
    w('- La raison est toujours affichée : « synergie : Baron, chaque Roi tenu compte deux fois ».')
    w('- **« Synergies à chercher »** (panneau de la boutique) : les pièces S et A qui manquent à vos jokers.')
    w('- Vos corrections (touche « Mon choix », raison « synergie ») augmentent le poids des synergies comptées (×1,5')
    w('  au plus).')
    w(string.format('- Réglages actuels (`engine/builds.lua`) : liste %s, objets %s, synergies déjà mesurées %s, règles générales %s ;',
        tostring(BD.LIST_SCALE), tostring(BD.ITEM_SCALE), tostring(BD.STATIC_SCALE), tostring(BD.GENERIC_SCALE)))
    w(string.format('  %d synergies de la liste sont affichées seulement (°). Mesures : `docs/TRAINING.md`, « Résultats 1.0.12 ».', n_shown))
    w()
    w('## Règles générales (engine/builds.lua)')
    w()
    w('- Deux jokers de la **même main** (Jolly + Sly, Crazy + Devious, Four Fingers + Droll…) : B, A si l\'un est un ×Mult.')
    w('- Une main qui en **contient** une autre (un Brelan contient une Paire : Zany + Jolly) : C.')
    w('- Deux jokers de la **même couleur** (Lusty + Bloodstone…) : B, A si l\'un est un ×Mult ; Blackboard avec Pique ou Trèfle : B.')
    w('- Un joker de couleur et un joker de **Couleur** (la main) : C. Deux couleurs différentes : −C (deux decks à construire),')
    w('  sauf avec Smeared Joker et deux couleurs de même teinte : B.')
    w('- **Blueprint / Brainstorm** avec un ×Mult ou un redéclencheur compatible (le jeu l\'indique sur la carte) : A ;')
    w('  le joker ×Mult acheté quand une copie est déjà là : B.')
    w('- Une paire nommée dans les listes remplace toujours la règle générale pour les deux mêmes jokers.')
    w('- Ces règles portent sur des effets que le moteur de score mesure déjà : elles sont affichées, et comptées')
    w('  seulement si `GENERIC_SCALE` n\'est pas 0.')
    w()
    w('## Par joker')
    w()
    for _, k in ipairs(keys) do
        local list = by[k]
        if list then
            table.sort(list, function(a, b)
                if TIER_ORDER[a.tier] ~= TIER_ORDER[b.tier] then return TIER_ORDER[a.tier] < TIER_ORDER[b.tier] end
                if (a.item and 1 or 0) ~= (b.item and 1 or 0) then return not a.item end
                return a.other:lower() < b.other:lower()
            end)
            w('### ' .. name(k))
            w()
            for _, e in ipairs(list) do
                w(string.format('- **%s%s** %s — %s', e.tier, e.shown and '°' or '', e.other, e.why))
            end
            w()
        else
            w('### ' .. name(k))
            w()
            w('- (règles générales seulement)')
            w()
        end
    end
    w('## Builds')
    w()
    for _, b in ipairs(BD.BUILDS) do
        w('### ' .. b.name .. ' — ' .. (TIER_LABEL[b.tier] or b.tier))
        w()
        local function names(l) local t = {} for _, x in ipairs(l or {}) do t[#t + 1] = name(x) end return table.concat(t, ', ') end
        w('- Pièces centrales : ' .. names(b.core))
        if b.support and #b.support > 0 then w('- Soutiens : ' .. names(b.support)) end
        if b.anti and #b.anti > 0 then w('- À éviter : ' .. names(b.anti)) end
        if b.tip then w('- Conseil : ' .. b.tip) end
        w()
    end
    w('## Niveaux')
    w()
    for _, t in ipairs({ 'S', 'A', 'B', 'C', 'X' }) do w('- **' .. t .. '** : ' .. TIER_LABEL[t]:match('%((.*)%)')) end
    w('- **°** : déjà mesurée par le moteur de score : affichée, pas comptée une seconde fois')
    return table.concat(out, '\n') .. '\n'
end

if mode == '--module' then return DOC end

-- script: bootstrap the mod like the trainer does, then write the file
local here = (arg and arg[0] and arg[0]:match('^(.*)[/\\][^/\\]+$')) or 'tools'
local REPO = here .. '/..'
package.path = REPO .. '/tests/?.lua;' .. package.path
local T = require('testlib')
T.MOD_ROOT = REPO .. '/BalatroStrategicCopilot'
T.REPO_ROOT = REPO
T.bootstrap()
local text = DOC.render()
local path = arg and arg[1]
if path then
    local f = assert(io.open(path, 'wb'))
    f:write(text)
    f:close()
    print('written: ' .. path)
else
    io.write(text)
end
