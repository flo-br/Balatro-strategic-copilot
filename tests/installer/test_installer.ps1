# Scenario tests for installer/outils/installer_copilot.ps1 (run with PowerShell 7 on any OS):
#   pwsh -NoProfile -File tests/installer/test_installer.ps1 -Zip dist/BalatroStrategicCopilot-<v>.zip [-Smods <steamodded source dir>] [-Work <dir>]
# Each scenario builds a fake Windows layout (Steam libraries, game folders, %AppData%\Balatro\Mods,
# Downloads, Lovely logs), runs the installer extracted from the REAL package, then checks the result.
# Windows itself (registry, Steam, the game) is not involved: see docs/TESTS.md.
param(
    [Parameter(Mandatory = $true)][string]$Zip,
    [string]$Smods = '',
    [string]$Work = ''
)
$ErrorActionPreference = 'Stop'
$Zip = (Resolve-Path $Zip).Path
if (-not $Work) { $Work = Join-Path ([IO.Path]::GetTempPath()) ("bsc_installer_tests_" + [guid]::NewGuid().ToString('N').Substring(0, 8)) }
if (Test-Path $Work) { Remove-Item -Recurse -Force $Work }
New-Item -ItemType Directory -Force -Path $Work | Out-Null
$Pwsh = (Get-Process -Id $PID).Path
$script:pass = 0; $script:fail = 0
$Results = @{}

function Check([bool]$cond, [string]$msg) {
    if ($cond) { $script:pass++; Write-Host "    ok   $msg" -ForegroundColor Green }
    else { $script:fail++; Write-Host "    FAIL $msg" -ForegroundColor Red }
}
function New-Dossier([string]$p) { New-Item -ItemType Directory -Force -Path $p | Out-Null; return $p }
function New-Exe([string]$dir) { New-Dossier $dir | Out-Null; [IO.File]::WriteAllBytes((Join-Path $dir 'Balatro.exe'), [byte[]](0x4D, 0x5A, 0, 0)) }
function New-Dll([string]$p) { [IO.File]::WriteAllBytes($p, [byte[]](0x4D, 0x5A, 0x90, 0, 3, 0, 0, 0)) }
function New-Smods([string]$dir) {
    if ($Smods) { Copy-Item -Recurse -LiteralPath $Smods -Destination $dir; return }
    New-Dossier (Join-Path $dir 'src') | Out-Null; New-Dossier (Join-Path $dir 'lovely') | Out-Null
    Set-Content -LiteralPath (Join-Path $dir 'version.lua') -Value 'return "1.0.0~BETA-0509c-STEAMODDED"'
    Set-Content -LiteralPath (Join-Path (Join-Path $dir 'src') 'core.lua') -Value '-- core'
    Set-Content -LiteralPath (Join-Path (Join-Path $dir 'lovely') 'core.toml') -Value '[manifest]'
    Set-Content -LiteralPath (Join-Path $dir 'manifest.json') -Value '{ "name": "Steamodded", "version_number": "1.0.0" }'
}
function New-LovelyZip([string]$path) {
    $tmp = New-Dossier (Join-Path $Work ("lz_" + [guid]::NewGuid().ToString('N').Substring(0, 6)))
    New-Dll (Join-Path $tmp 'winmm.dll')
    Set-Content -LiteralPath (Join-Path $tmp 'README.md') -Value 'lovely'
    Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $path
}
function New-Package([string]$dest) { Expand-Archive -LiteralPath $Zip -DestinationPath $dest; return $dest }
function Invoke-Installer([string]$pkg, [string[]]$a) {
    $out = & $Pwsh -NoProfile -File (Join-Path (Join-Path $pkg 'outils') 'installer_copilot.ps1') @a 2>&1 | Out-String
    return @{ Out = $out; Code = $LASTEXITCODE }
}
function Get-Report([string]$p) { if (Test-Path $p) { return (Get-Content -LiteralPath $p -Raw) } return '' }
function Write-LovelyLog([string]$mods, [string]$game, [string[]]$extra, [string]$name = 'lovely-2026.10.18-12.00.00.log') {
    $dir = New-Dossier (Join-Path (Join-Path $mods 'lovely') 'log')
    $l = @('INFO - [♥] Lovely 0.7.1', "INFO - [♥] Game directory is at `"$($game -replace '\\', '\\')`"",
        "INFO - [♥] Using mod directory at `"$($mods -replace '\\', '\\')`"") + $extra
    [IO.File]::WriteAllLines((Join-Path $dir $name), $l)
    return (Join-Path $dir $name)
}
$SmodsLine = 'INFO - [G] 2026-10-18 12:00:00 :: INFO  :: SMODS :: Steamodded v1.0.0~BETA-0509c-STEAMODDED'
$ReadyLine = 'INFO - [G] 2026-10-18 12:00:02 :: INFO  :: BSCopilot :: boot: Balatro Strategic Copilot 1.0.7 ready (update=true draw=true events=true keys=true)'
$Version = ((Expand-Archive -LiteralPath $Zip -DestinationPath (Join-Path $Work 'v') -PassThru | Where-Object { $_.Name -eq 'BalatroStrategicCopilot.json' } | Select-Object -First 1 | Get-Content -Raw) | ConvertFrom-Json).version

# ---------------------------------------------------------------------------------------------
Write-Host "S1 jeu réinstallé dans une autre bibliothèque : Lovely manquant, ancienne copie imbriquée + zip du mod"
$T = New-Dossier (Join-Path $Work 'S1')
$steam = New-Dossier (Join-Path $T 'Steam'); $newlib = New-Dossier (Join-Path $T 'NewLib')
New-Dossier (Join-Path $steam 'steamapps') | Out-Null; New-Dossier (Join-Path $newlib 'steamapps') | Out-Null
Set-Content -LiteralPath (Join-Path (Join-Path $steam 'steamapps') 'libraryfolders.vdf') -Value @"
"libraryfolders"
{
	"0"
	{
		"path"		"$steam"
	}
	"1"
	{
		"path"		"$newlib"
		"apps"
		{
			"2379780"		"123"
		}
	}
}
"@
Set-Content -LiteralPath (Join-Path (Join-Path $newlib 'steamapps') 'appmanifest_2379780.acf') -Value "`"AppState`"`n{`n`t`"appid`"`t`t`"2379780`"`n`t`"installdir`"`t`t`"Balatro`"`n}"
$oldGame = Join-Path (Join-Path (Join-Path $steam 'steamapps') 'common') 'Balatro'; New-Exe $oldGame; New-Dll (Join-Path $oldGame 'winmm.dll')
$newGame = Join-Path (Join-Path (Join-Path $newlib 'steamapps') 'common') 'Balatro'; New-Exe $newGame
$mods = New-Dossier (Join-Path (Join-Path (Join-Path $T 'AppData') 'Balatro') 'Mods')
New-Smods (Join-Path $mods 'smods-main')
$mp = New-Dossier (Join-Path $mods 'BalatroMultiplayer')
Set-Content -LiteralPath (Join-Path $mp 'Multiplayer.json') -Value '{ "id": "Multiplayer", "main_file": "main.lua", "version": "0.2.x", "dependencies": ["Steamodded (>=1.0.0~BETA-0711a)"] }'
$nested = New-Dossier (Join-Path (Join-Path $mods 'BalatroStrategicCopilot') 'balatro-strategic-copilot-main')
Expand-Archive -LiteralPath $Zip -DestinationPath (Join-Path $Work 'S1src')
Copy-Item -Recurse -LiteralPath (Join-Path (Join-Path $Work 'S1src') 'BalatroStrategicCopilot') -Destination (Join-Path $nested 'BalatroStrategicCopilot')
Copy-Item -LiteralPath $Zip -Destination (Join-Path $mods 'BalatroStrategicCopilot-1.0.2.zip')
Write-LovelyLog $mods $oldGame @($SmodsLine) | Out-Null
(Get-Item (Get-ChildItem (Join-Path (Join-Path $mods 'lovely') 'log'))[0].FullName).LastWriteTime = (Get-Date).AddDays(-3)
(Get-Item (Join-Path $newGame 'Balatro.exe')).LastWriteTime = (Get-Date).AddDays(-1)
$pkg = New-Package (Join-Path $T 'Telechargements/BalatroStrategicCopilot-x')
$rep = Join-Path $T 'rapport.txt'
$r = Invoke-Installer $pkg @('-Oui', '-SansLancement', '-RacinesSteam', $steam, '-DossierAppData', (Join-Path $T 'AppData'),
    '-DossierTelechargements', (Join-Path $T 'vide'), '-Rapport', $rep)
$txt = Get-Report $rep
Check ($txt -match [regex]::Escape("Jeu : $newGame")) 'jeu choisi = installation déclarée à Steam (nouvelle bibliothèque)'
Check ($txt -match 'Autre installation trouvée') 'ancienne installation signalée'
Check ($txt -match 'Lovely est ABSENT') 'Lovely manquant détecté'
Check (Test-Path (Join-Path $newGame 'winmm.dll')) 'winmm.dll copié depuis l''ancienne installation'
Check ($txt -match 'Steamodded 1\.0\.0~BETA-0509c') 'Steamodded détecté avec sa version'
Check ($txt -match 'Multiplayer 0\.2\.x, dépend de : Steamodded') 'autres mods listés avec leurs dépendances'
Check (Test-Path (Join-Path (Join-Path $mods 'BalatroStrategicCopilot') 'BalatroStrategicCopilot.json')) 'copilote installé au bon endroit'
$copies = @(Get-ChildItem -LiteralPath $mods -Recurse -Filter 'BalatroStrategicCopilot.json')
Check ($copies.Count -eq 1) "une seule copie dans Mods ($($copies.Count))"
Check (@(Get-ChildItem -LiteralPath $mods -Filter '*.zip').Count -eq 0) 'zip du mod sorti de Mods'
$bk = Join-Path (Join-Path $T 'AppData') 'Balatro/BSC_anciennes_copies'
Check (@(Get-ChildItem -LiteralPath $bk -Recurse -Filter 'BalatroStrategicCopilot.json').Count -eq 1 -and @(Get-ChildItem -LiteralPath $bk -Recurse -Filter '*.zip').Count -eq 1) 'anciennes copies conservées hors de Mods (rien supprimé)'
$ver = (Get-Content -Raw (Join-Path (Join-Path $mods 'BalatroStrategicCopilot') 'BalatroStrategicCopilot.json') | ConvertFrom-Json).version
Check ($ver -eq $Version) "version installée = $Version"
Check ($txt -match 'date d''AVANT les corrections') 'ancien journal signalé comme antérieur aux corrections'
Check ($r.Code -eq 0) "aucun bloquant restant (code $($r.Code))"
$Results.S1Mods = $mods

# ---------------------------------------------------------------------------------------------
Write-Host "S2 diagnostic seul après lancement réussi (journal récent : copilote prêt)"
Write-LovelyLog $mods $newGame @("INFO - [♥] Applied 97 patches to 'game.lua'", $SmodsLine,
    'INFO - [G] 2026-10-18 12:00:01 :: INFO  :: Loader :: Valid JSON file found', $ReadyLine) 'lovely-2026.10.18-13.00.00.log' | Out-Null
$before = (Get-ChildItem -LiteralPath $mods -Recurse | Measure-Object).Count
$rep = Join-Path $T 'rapport2.txt'
$r = Invoke-Installer $pkg @('-DiagnosticSeul', '-RacinesSteam', $steam, '-DossierAppData', (Join-Path $T 'AppData'), '-DossierTelechargements', (Join-Path $T 'vide'), '-Rapport', $rep)
$txt = Get-Report $rep
Check ($txt -match 'Lovely 0\.7\.1 a démarré') 'Lovely vu dans le journal'
Check ($txt -match 'Steamodded 1\.0\.0~BETA-0509c-STEAMODDED chargé \(97') 'Steamodded chargé + nombre de patchs'
Check ($txt -match 'Le copilote a démarré') 'copilote prêt détecté'
Check ($r.Code -eq 0) "code 0 ($($r.Code))"
Check ((Get-ChildItem -LiteralPath $mods -Recurse | Measure-Object).Count -eq $before) 'diagnostic : aucune modification'

# ---------------------------------------------------------------------------------------------
Write-Host "S3 Steamodded rangé trop bas + doublon, ancien version.dll avec winmm.dll, options --vanilla, .lovelyignore"
$T = New-Dossier (Join-Path $Work 'S3')
$steam = New-Dossier (Join-Path $T 'Steam'); New-Dossier (Join-Path $steam 'steamapps') | Out-Null
Set-Content -LiteralPath (Join-Path (Join-Path $steam 'steamapps') 'appmanifest_2379780.acf') -Value '"installdir"		"Balatro"'
$game = Join-Path (Join-Path (Join-Path $steam 'steamapps') 'common') 'Balatro'; New-Exe $game
New-Dll (Join-Path $game 'winmm.dll'); New-Dll (Join-Path $game 'version.dll')
$cfg = New-Dossier (Join-Path (Join-Path (Join-Path $steam 'userdata') '12345') 'config')
Set-Content -LiteralPath (Join-Path $cfg 'localconfig.vdf') -Value "`"apps`"`n{`n`"2379780`"`n{`n`"LaunchOptions`"`t`t`"--vanilla`"`n}`n`"620`"`n{`n`"LaunchOptions`"`t`t`"-novid`"`n}`n}"
$mods = New-Dossier (Join-Path $T 'AppData/Balatro/Mods')
New-Smods (Join-Path (New-Dossier (Join-Path $mods 'smods-main')) 'smods-main')
New-Smods (Join-Path $mods 'smods-old')
Set-Content -LiteralPath (Join-Path (Join-Path $mods 'smods-old') '.lovelyignore') -Value ''
(Get-Item (Join-Path $mods 'smods-old')).LastWriteTime = (Get-Date).AddDays(-30)
$pkg = New-Package (Join-Path $T 'pkg')
$rep = Join-Path $T 'rapport.txt'
$r = Invoke-Installer $pkg @('-Oui', '-SansLancement', '-RacinesSteam', $steam, '-DossierAppData', (Join-Path $T 'AppData'), '-DossierTelechargements', (Join-Path $T 'vide'), '-Rapport', $rep)
$txt = Get-Report $rep
Check ($txt -match 'désactivent les mods : « --vanilla »') 'option --vanilla détectée (et pas celle d''un autre jeu)'
Check (-not ($txt -match '-novid')) 'options d''un autre jeu ignorées'
Check ((Test-Path (Join-Path $game 'version.dll.ancien-lovely')) -and -not (Test-Path (Join-Path $game 'version.dll'))) 'ancien version.dll renommé (réversible)'
Check ((Test-Path (Join-Path (Join-Path $mods 'smods-main-steamodded') 'lovely')) -or (Test-Path (Join-Path (Join-Path $mods 'smods-main') 'lovely'))) 'Steamodded imbriqué remonté directement dans Mods'
$sm = @(Get-ChildItem -LiteralPath $mods -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'lovely') })
Check ($sm.Count -eq 1) "une seule copie de Steamodded reste dans Mods ($($sm.Count))"
Check ($r.Code -eq 1) "bloquant restant signalé (--vanilla) : code $($r.Code)"

# ---------------------------------------------------------------------------------------------
Write-Host "S4 Steamodded absent, Lovely absent : archives officielles dans Téléchargements"
$T = New-Dossier (Join-Path $Work 'S4')
$game = Join-Path $T 'Steam/steamapps/common/Balatro'; New-Exe $game
$dl = New-Dossier (Join-Path $T 'Downloads')
New-LovelyZip (Join-Path $dl 'lovely-x86_64-pc-windows-msvc.zip')
$smz = New-Dossier (Join-Path $Work 'S4smods'); New-Smods (Join-Path $smz 'smods-1.0.0-beta')
Compress-Archive -Path (Join-Path $smz 'smods-1.0.0-beta') -DestinationPath (Join-Path $dl 'smods-1.0.0-beta.zip')
$pkg = New-Package (Join-Path $T 'pkg')
$rep = Join-Path $T 'rapport.txt'
$r = Invoke-Installer $pkg @('-Oui', '-SansLancement', '-DossierJeu', $game, '-DossierAppData', (Join-Path $T 'AppData'), '-DossierTelechargements', $dl, '-Rapport', $rep)
$txt = Get-Report $rep
$mods = Join-Path $T 'AppData/Balatro/Mods'
Check (Test-Path (Join-Path $game 'winmm.dll')) 'winmm.dll extrait de l''archive Lovely'
Check (Test-Path (Join-Path (Join-Path $mods 'smods') 'lovely')) 'Steamodded extrait directement dans Mods\smods'
Check (Test-Path (Join-Path $mods 'BalatroStrategicCopilot/BalatroStrategicCopilot.json')) 'copilote installé'
Check ($txt -match 'Aucun journal de Lovely') 'absence de journal expliquée'
Check ($r.Code -eq 0) "code 0 ($($r.Code))"
$Results.S4Mods = $mods

# ---------------------------------------------------------------------------------------------
Write-Host "S5 paquet extrait DANS Mods et lancé depuis là"
$T = New-Dossier (Join-Path $Work 'S5')
$game = Join-Path $T 'Game'; New-Exe $game; New-Dll (Join-Path $game 'winmm.dll')
$mods = New-Dossier (Join-Path $T 'AppData/Balatro/Mods'); New-Smods (Join-Path $mods 'smods')
$pkg = New-Package (Join-Path $mods 'BalatroStrategicCopilot-1.0.3')
$rep = Join-Path $T 'rapport.txt'
$r = Invoke-Installer $pkg @('-Oui', '-SansLancement', '-DossierJeu', $game, '-DossierAppData', (Join-Path $T 'AppData'), '-DossierTelechargements', (Join-Path $T 'vide'), '-Rapport', $rep)
$txt = Get-Report $rep
$copies = @(Get-ChildItem -LiteralPath $mods -Recurse -Filter 'BalatroStrategicCopilot.json')
Check ($copies.Count -eq 1 -and $copies[0].FullName -eq (Join-Path $mods 'BalatroStrategicCopilot/BalatroStrategicCopilot.json')) "une seule copie, au bon endroit ($($copies.Count))"
Check ($txt -match 'extrait DANS Mods') 'utilisateur prévenu de sortir le paquet de Mods'
Check (Test-Path (Join-Path $pkg 'outils/installer_copilot.ps1')) 'le programme en cours n''a pas été déplacé'
Check ($r.Code -eq 0) "code 0 ($($r.Code))"
$Results.S5Mods = $mods

# ---------------------------------------------------------------------------------------------
Write-Host "S6 diagnostics de journaux (Steamodded absent, copilote absent, erreur, autre dossier Mods, vanilla, plantage)"
$cases = @(
    @{ N = 'smods'; L = @("INFO - [♥] Applied 3 patches to 'game.lua'"); E = "Steamodded ne s'est pas chargé" },
    @{ N = 'absent'; L = @($SmodsLine); E = 'le copilote n''apparaît pas' },
    @{ N = 'erreur'; L = @($SmodsLine, 'INFO - [G] 2026-10-18 12:00:02 :: ERROR :: BSCopilot :: Balatro Strategic Copilot failed to start: [SMODS BalatroStrategicCopilot "src/game/boot.lua"]:12: boom'); E = 'erreur au démarrage : .*boom' },
    @{ N = 'vanilla'; L = @('INFO - [♥] Running in vanilla mode'); E = 'mode « vanilla »' },
    @{ N = 'crash'; L = @($SmodsLine, $ReadyLine, 'INFO - [G] 2026-10-18 12:01:00 :: ERROR :: StackTrace :: Oops! The game crashed', 'attempt to index nil'); E = 'Le jeu a planté' }
)
foreach ($c in $cases) {
    $T = New-Dossier (Join-Path $Work ('S6_' + $c.N))
    $game = Join-Path $T 'Game'; New-Exe $game; New-Dll (Join-Path $game 'winmm.dll')
    (Get-Item (Join-Path $game 'Balatro.exe')).LastWriteTime = (Get-Date).AddDays(-1)
    $mods = New-Dossier (Join-Path $T 'AppData/Balatro/Mods'); New-Smods (Join-Path $mods 'smods')
    Write-LovelyLog $mods $game $c.L | Out-Null
    $pkg = New-Package (Join-Path $T 'pkg')
    $rep = Join-Path $T 'rapport.txt'
    $r = Invoke-Installer $pkg @('-DiagnosticSeul', '-DossierJeu', $game, '-DossierAppData', (Join-Path $T 'AppData'), '-DossierTelechargements', (Join-Path $T 'vide'), '-Rapport', $rep)
    $txt = Get-Report $rep
    Check ($txt -match $c.E) "$($c.N) : « $($c.E) »"
    Check ($r.Code -eq 1) "$($c.N) : code 1 ($($r.Code))"
}
$T = New-Dossier (Join-Path $Work 'S6_autre')
$game = Join-Path $T 'Game'; New-Exe $game; New-Dll (Join-Path $game 'winmm.dll')
(Get-Item (Join-Path $game 'Balatro.exe')).LastWriteTime = (Get-Date).AddDays(-1)
$mods = New-Dossier (Join-Path $T 'AppData/Balatro/Mods')
$dir = New-Dossier (Join-Path $mods 'lovely/log')
[IO.File]::WriteAllLines((Join-Path $dir 'lovely-2026.10.18-12.00.00.log'), @('INFO - [♥] Lovely 0.9.0', 'INFO - [♥] Using mod directory at "/ailleurs/Mods"'))
$pkg = New-Package (Join-Path $T 'pkg')
$rep = Join-Path $T 'rapport.txt'
$r = Invoke-Installer $pkg @('-DiagnosticSeul', '-DossierJeu', $game, '-DossierAppData', (Join-Path $T 'AppData'), '-DossierTelechargements', (Join-Path $T 'vide'), '-Rapport', $rep)
Check ((Get-Report $rep) -match 'AUTRE dossier Mods : /ailleurs/Mods') 'autre dossier Mods signalé'

# ---------------------------------------------------------------------------------------------
Write-Host "S7 lancement du jeu puis lecture du journal écrit pendant l'attente"
$T = New-Dossier (Join-Path $Work 'S7')
$game = Join-Path $T 'Game'; New-Exe $game; New-Dll (Join-Path $game 'winmm.dll')
$mods = New-Dossier (Join-Path $T 'AppData/Balatro/Mods'); New-Smods (Join-Path $mods 'smods')
$pkg = New-Package (Join-Path $T 'pkg')
$rep = Join-Path $T 'rapport.txt'
$job = Start-Job -ScriptBlock {
    param($mods, $game, $l1, $l2)
    Start-Sleep -Seconds 6
    $dir = New-Item -ItemType Directory -Force -Path (Join-Path (Join-Path $mods 'lovely') 'log')
    [IO.File]::WriteAllLines((Join-Path $dir.FullName 'lovely-2026.10.18-14.00.00.log'), @('INFO - [♥] Lovely 0.7.1', "INFO - [♥] Using mod directory at `"$mods`"", $l1, $l2))
} -ArgumentList $mods, $game, $SmodsLine, $ReadyLine
$t0 = Get-Date
$r = Invoke-Installer $pkg @('-Oui', '-AttenteSecondes', '40', '-DossierJeu', $game, '-DossierAppData', (Join-Path $T 'AppData'), '-DossierTelechargements', (Join-Path $T 'vide'), '-Rapport', $rep)
$dt = ((Get-Date) - $t0).TotalSeconds
Receive-Job $job -Wait -AutoRemoveJob | Out-Null
$txt = Get-Report $rep
Check ($txt -match 'Le copilote a démarré') 'journal écrit après le lancement détecté, copilote prêt'
Check ($dt -lt 35) ("arrêt dès que le copilote est prêt ({0:N0} s)" -f $dt)
Check ($r.Code -eq 0) "code 0 ($($r.Code))"

# ---------------------------------------------------------------------------------------------
Write-Host "S8 paquet incomplet (dossier du mod absent)"
$T = New-Dossier (Join-Path $Work 'S8')
$pkg = New-Package (Join-Path $T 'pkg'); Remove-Item -Recurse -Force (Join-Path $pkg 'BalatroStrategicCopilot')
$game = Join-Path $T 'Game'; New-Exe $game; New-Dll (Join-Path $game 'winmm.dll')
$rep = Join-Path $T 'rapport.txt'
$r = Invoke-Installer $pkg @('-Oui', '-SansLancement', '-DossierJeu', $game, '-DossierAppData', (Join-Path $T 'AppData'), '-DossierTelechargements', (Join-Path $T 'vide'), '-Rapport', $rep)
Check ((Get-Report $rep) -match 'Extrayez TOUTE l''archive') 'message clair'
Check ($r.Code -eq 1) "code 1 ($($r.Code))"

# ---------------------------------------------------------------------------------------------
Write-Host "S9 copilote désactivé depuis le menu Mods d'un Steamodded récent (Mods\lovely\blacklist.txt)"
$T = New-Dossier (Join-Path $Work 'S9')
$game = Join-Path $T 'Game'; New-Exe $game; New-Dll (Join-Path $game 'winmm.dll')
$mods = New-Dossier (Join-Path $T 'AppData/Balatro/Mods'); New-Smods (Join-Path $mods 'smods')
$lbdir = New-Dossier (Join-Path $mods 'lovely')
[IO.File]::WriteAllLines((Join-Path $lbdir 'blacklist.txt'), @('# commentaire', 'AutreMod', 'BalatroStrategicCopilot'))
$pkg = New-Package (Join-Path $T 'pkg')
$rep = Join-Path $T 'rapport.txt'
$r = Invoke-Installer $pkg @('-Oui', '-SansLancement', '-DossierJeu', $game, '-DossierAppData', (Join-Path $T 'AppData'), '-DossierTelechargements', (Join-Path $T 'vide'), '-Rapport', $rep)
$bl = @(Get-Content -LiteralPath (Join-Path $lbdir 'blacklist.txt'))
Check (-not ($bl -contains 'BalatroStrategicCopilot')) 'copilote retiré de la liste des mods désactivés'
Check (($bl -contains 'AutreMod') -and ($bl -contains '# commentaire')) 'les autres lignes sont conservées'
Check (@(Get-ChildItem -LiteralPath $lbdir -Filter 'blacklist.txt.sauvegarde-*').Count -eq 1) 'copie de sécurité de blacklist.txt'
Check ($r.Code -eq 0) "code 0 ($($r.Code))"
$Results.S9Mods = $mods

Write-Host ''
Write-Host "Mods à vérifier avec le vrai chargeur : S1=$($Results.S1Mods) S4=$($Results.S4Mods) S5=$($Results.S5Mods) S9=$($Results.S9Mods)"
Write-Host "$($script:pass) réussis, $($script:fail) échecs"
if ($script:fail -gt 0) { exit 1 }
exit 0
