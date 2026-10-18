<#
.SYNOPSIS
    Balatro Strategic Copilot : installation et diagnostic complets (Windows).

.DESCRIPTION
    Vérifie toute la chaîne nécessaire pour que le copilote apparaisse dans Balatro :
      1. le dossier du jeu (trouvé via Steam),
      2. Lovely (winmm.dll à côté de Balatro.exe),
      3. Steamodded (dans %AppData%\Balatro\Mods),
      4. le copilote lui-même (au bon endroit, une seule copie),
      5. après lancement du jeu : le journal de Lovely (Steamodded chargé ? copilote prêt ?).
    Chaque modification est proposée et doit être acceptée (sauf avec -Oui).

    Ce script ne télécharge rien, n'envoie rien sur Internet, ne modifie ni les fichiers
    d'origine du jeu ni les sauvegardes. Les anciennes copies sont déplacées, jamais supprimées.
    Il peut seulement ouvrir une page web officielle dans le navigateur si vous l'acceptez.

.PARAMETER DiagnosticSeul
    Ne modifie rien : vérifie et analyse le dernier journal de Lovely.
.PARAMETER Oui
    Répond « oui » à toutes les questions (utilisé par les tests).
#>
[CmdletBinding()]
param(
    [string]$DossierJeu = '',
    [string]$DossierAppData = '',
    [string]$DossierTelechargements = '',
    [string[]]$RacinesSteam = @(),
    [switch]$DiagnosticSeul,
    [switch]$Oui,
    [switch]$SansLancement,
    [int]$AttenteSecondes = 150,
    [string]$Rapport = ''
)

$ErrorActionPreference = 'Continue'
$AppId = '2379780'
$Debut = Get-Date
$Horodatage = $Debut.ToString('yyyyMMdd-HHmmss')
$Journal = New-Object System.Collections.Generic.List[string]
$Bloquants = New-Object System.Collections.Generic.List[string]
$Avertissements = New-Object System.Collections.Generic.List[string]
$script:Modifs = 0

# ---------------------------------------------------------------------------------------------
# Affichage, questions, chemins
# ---------------------------------------------------------------------------------------------

function Write-Ligne([string]$genre, [string]$texte) {
    switch ($genre) {
        'titre' { $ligne = "`r`n=== $texte ==="; $couleur = 'Cyan' }
        'ok'    { $ligne = "[OK] $texte"; $couleur = 'Green' }
        'warn'  { $ligne = "[!!] $texte"; $couleur = 'Yellow'; $Avertissements.Add($texte) }
        'err'   { $ligne = "[XX] $texte"; $couleur = 'Red'; $Bloquants.Add($texte) }
        'fait'  { $ligne = "[->] $texte"; $couleur = 'Magenta'; $script:Modifs++ }
        default { $ligne = "     $texte"; $couleur = 'Gray' }
    }
    Write-Host $ligne -ForegroundColor $couleur
    $Journal.Add($ligne)
}

function Read-Oui([string]$question) {
    if ($DiagnosticSeul) { return $false }
    if ($Oui) { $Journal.Add("     $question -> oui (automatique)"); return $true }
    while ($true) {
        $r = Read-Host "$question [O/n]"
        if ($null -eq $r) { return $false }
        $r = $r.Trim().ToLower()
        if ($r -eq '' -or $r -eq 'o' -or $r -eq 'oui' -or $r -eq 'y' -or $r -eq 'yes') {
            $Journal.Add("     $question -> oui"); return $true
        }
        if ($r -eq 'n' -or $r -eq 'non' -or $r -eq 'no') { $Journal.Add("     $question -> non"); return $false }
        Write-Host '     Répondez O (oui) ou N (non).'
    }
}

function Wait-Entree([string]$message) {
    if ($Oui -or $DiagnosticSeul) { return '' }
    $r = Read-Host $message
    if ($null -eq $r) { return 'n' }
    return $r.Trim().ToLower()
}

function Join-Chemin([string]$a, [string]$b) { return [System.IO.Path]::Combine($a, $b) }

function Test-Fichier([string]$p) { return ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) }
function Test-Dossier([string]$p) { return ($p -and (Test-Path -LiteralPath $p -PathType Container)) }

function Get-CheminNormal([string]$p) {
    if (-not $p) { return '' }
    try { $p = [System.IO.Path]::GetFullPath($p) } catch { }
    return $p.TrimEnd('\', '/')
}

function Test-MemeChemin([string]$a, [string]$b) {
    return ((Get-CheminNormal $a).ToLowerInvariant() -eq (Get-CheminNormal $b).ToLowerInvariant())
}

function Test-SousChemin([string]$enfant, [string]$parent) {
    $e = (Get-CheminNormal $enfant).ToLowerInvariant()
    $p = (Get-CheminNormal $parent).ToLowerInvariant()
    if (-not $e -or -not $p) { return $false }
    return ($e -eq $p -or $e.StartsWith($p + [System.IO.Path]::DirectorySeparatorChar))
}

function Read-Partage([string]$p) {
    # lecture même si le jeu (Lovely) a encore le fichier ouvert
    $fs = [System.IO.File]::Open($p, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
        return $sr.ReadToEnd()
    } finally { $fs.Dispose() }
}

function Test-EnTeteMZ([string]$p) {
    try {
        $fs = [System.IO.File]::OpenRead($p)
        try { $b1 = $fs.ReadByte(); $b2 = $fs.ReadByte() } finally { $fs.Dispose() }
        return ($b1 -eq 0x4D -and $b2 -eq 0x5A)
    } catch { return $false }
}

function Move-VersSauvegarde([string]$source, [string]$racineSauvegarde) {
    if (-not (Test-Dossier $racineSauvegarde)) { New-Item -ItemType Directory -Force -Path $racineSauvegarde | Out-Null }
    $nom = Split-Path -Leaf $source
    $dest = Join-Chemin $racineSauvegarde $nom
    $i = 2
    while (Test-Path -LiteralPath $dest) { $dest = Join-Chemin $racineSauvegarde ("$nom ($i)"); $i++ }
    Move-Item -LiteralPath $source -Destination $dest -ErrorAction Stop
    return $dest
}

function Open-Page([string]$url) {
    try { Start-Process $url | Out-Null; return $true } catch { return $false }
}

function Remove-ListeNoire([string]$fichier, [string]$nom) {
    # Mods\lovely\blacklist.txt : c'est là que les Steamodded récents notent les mods désactivés
    # depuis le menu Mods. Copie de sécurité, puis retrait de la seule ligne concernée.
    try {
        Copy-Item -LiteralPath $fichier -Destination "$fichier.sauvegarde-$Horodatage" -ErrorAction Stop
        $lignes = @(Get-Content -LiteralPath $fichier -ErrorAction Stop | Where-Object { $_.Trim() -ne $nom })
        [System.IO.File]::WriteAllLines($fichier, [string[]]$lignes)
        Write-Ligne 'fait' "« $nom » retiré de $fichier (copie : $fichier.sauvegarde-$Horodatage)"
        return $true
    } catch { Write-Ligne 'err' "Impossible de modifier $fichier : $($_.Exception.Message)"; return $false }
}

Write-Host ''
Write-Host '  Balatro Strategic Copilot - installation et diagnostic' -ForegroundColor Cyan
Write-Host '  (ne joue jamais à votre place, ne télécharge rien, n''envoie rien)' -ForegroundColor DarkGray
if ($DiagnosticSeul) { Write-Host '  Mode DIAGNOSTIC : aucune modification ne sera faite.' -ForegroundColor DarkGray }
$Journal.Add("Balatro Strategic Copilot - installation/diagnostic, $($Debut.ToString('yyyy-MM-dd HH:mm:ss'))")
$Journal.Add("PowerShell $($PSVersionTable.PSVersion), $([System.Environment]::OSVersion.VersionString)")

# ---------------------------------------------------------------------------------------------
# 0. Paquet du copilote
# ---------------------------------------------------------------------------------------------
Write-Ligne 'titre' '0. Paquet du copilote'
$DossierScript = $PSScriptRoot
if (-not $DossierScript) { $DossierScript = Split-Path -Parent $MyInvocation.MyCommand.Path }
$RacinePaquet = Split-Path -Parent $DossierScript
$SourceMod = $null
foreach ($c in @((Join-Chemin $RacinePaquet 'BalatroStrategicCopilot'),
                 (Join-Chemin $DossierScript 'BalatroStrategicCopilot'),
                 (Join-Chemin (Split-Path -Parent $RacinePaquet) 'BalatroStrategicCopilot'))) {
    if (Test-Fichier (Join-Chemin $c 'BalatroStrategicCopilot.json')) { $SourceMod = Get-CheminNormal $c; break }
}
$VersionPaquet = '?'
if ($SourceMod) {
    try {
        $meta = Get-Content -LiteralPath (Join-Chemin $SourceMod 'BalatroStrategicCopilot.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $VersionPaquet = [string]$meta.version
        if ($meta.id -ne 'BalatroStrategicCopilot' -or -not (Test-Fichier (Join-Chemin $SourceMod $meta.main_file))) { throw 'fichiers incomplets' }
        Write-Ligne 'ok' "Copilote $VersionPaquet trouvé dans le paquet : $SourceMod"
    } catch {
        Write-Ligne 'err' "Le dossier du copilote du paquet est incomplet ($SourceMod) : réextrayez toute l'archive."
        $SourceMod = $null
    }
} else {
    Write-Ligne 'err' "Dossier BalatroStrategicCopilot introuvable à côté de ce script. Extrayez TOUTE l'archive puis relancez INSTALLER_COPILOT.bat depuis le dossier extrait."
}

# ---------------------------------------------------------------------------------------------
# 1. Dossier du jeu
# ---------------------------------------------------------------------------------------------
Write-Ligne 'titre' '1. Dossier du jeu (Balatro.exe)'

$enCours = @(Get-Process -Name 'Balatro' -ErrorAction SilentlyContinue)
if ($enCours.Count -gt 0) {
    Write-Ligne 'warn' 'Balatro est ouvert. Fermez complètement le jeu avant de continuer.'
    $null = Wait-Entree '     Appuyez sur Entrée une fois le jeu fermé'
}

$Candidats = New-Object System.Collections.Generic.List[object]
function Add-Candidat([string]$dossier, [string]$origine, [bool]$manifeste) {
    if (-not (Test-Fichier (Join-Chemin $dossier 'Balatro.exe'))) { return }
    $n = Get-CheminNormal $dossier
    foreach ($x in $Candidats) {
        if (Test-MemeChemin $x.Dossier $n) { if ($manifeste) { $x.Manifeste = $true; $x.Origine = $origine }; return }
    }
    $Candidats.Add([pscustomobject]@{ Dossier = $n; Origine = $origine; Manifeste = $manifeste;
        Date = (Get-Item -LiteralPath (Join-Chemin $n 'Balatro.exe')).LastWriteTime })
}

$RacinesSteamTrouvees = New-Object System.Collections.Generic.List[string]
foreach ($r in $RacinesSteam) { if ($r) { $RacinesSteamTrouvees.Add($r) } }
if ($RacinesSteam.Count -eq 0) {
    foreach ($cle in @(@('HKCU:\Software\Valve\Steam', 'SteamPath'),
                       @('HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'InstallPath'),
                       @('HKLM:\SOFTWARE\Valve\Steam', 'InstallPath'))) {
        try {
            $v = (Get-ItemProperty -Path $cle[0] -Name $cle[1] -ErrorAction Stop).($cle[1])
            if ($v) { $RacinesSteamTrouvees.Add(($v -replace '/', '\')) }
        } catch { }
    }
}
$Bibliotheques = New-Object System.Collections.Generic.List[string]
foreach ($racine in $RacinesSteamTrouvees) {
    if (-not (Test-Dossier $racine)) { continue }
    $Bibliotheques.Add($racine)
    foreach ($vdf in @((Join-Chemin (Join-Chemin $racine 'steamapps') 'libraryfolders.vdf'),
                       (Join-Chemin (Join-Chemin $racine 'config') 'libraryfolders.vdf'))) {
        if (-not (Test-Fichier $vdf)) { continue }
        $texte = Get-Content -LiteralPath $vdf -Raw -ErrorAction SilentlyContinue
        if (-not $texte) { continue }
        foreach ($m in [regex]::Matches($texte, '"path"\s+"([^"]+)"')) { $Bibliotheques.Add(($m.Groups[1].Value -replace '\\\\', '\')) }
        foreach ($m in [regex]::Matches($texte, '(?m)^\s*"\d+"\s+"([A-Za-z]:\\\\[^"]*)"')) { $Bibliotheques.Add(($m.Groups[1].Value -replace '\\\\', '\')) }
    }
}
foreach ($bib in $Bibliotheques) {
    $steamapps = Join-Chemin $bib 'steamapps'
    $acf = Join-Chemin $steamapps "appmanifest_$AppId.acf"
    if (Test-Fichier $acf) {
        $t = Get-Content -LiteralPath $acf -Raw -ErrorAction SilentlyContinue
        $m = [regex]::Match([string]$t, '"installdir"\s+"([^"]+)"')
        $nom = 'Balatro'
        if ($m.Success) { $nom = $m.Groups[1].Value }
        Add-Candidat (Join-Chemin (Join-Chemin $steamapps 'common') $nom) "Steam ($bib)" $true
    }
    Add-Candidat (Join-Chemin (Join-Chemin $steamapps 'common') 'Balatro') "bibliothèque Steam ($bib)" $false
}
# recherche sur les disques (anciennes installations, bibliothèques non déclarées)
$Relatifs = @('SteamLibrary\steamapps\common\Balatro', 'Steam\steamapps\common\Balatro',
    'Program Files (x86)\Steam\steamapps\common\Balatro', 'Program Files\Steam\steamapps\common\Balatro',
    'Games\SteamLibrary\steamapps\common\Balatro', 'Games\Steam\steamapps\common\Balatro',
    'Jeux\SteamLibrary\steamapps\common\Balatro', 'Jeux\Steam\steamapps\common\Balatro',
    'SteamGames\steamapps\common\Balatro')
$XboxTrouve = $null
try {
    foreach ($d in [System.IO.DriveInfo]::GetDrives()) {
        if (-not $d.IsReady) { continue }
        if ($d.DriveType -ne [System.IO.DriveType]::Fixed -and $d.DriveType -ne [System.IO.DriveType]::Removable) { continue }
        $racineDisque = $d.RootDirectory.FullName
        foreach ($rel in $Relatifs) { Add-Candidat (Join-Chemin $racineDisque $rel) "recherche sur le disque $racineDisque" $false }
        $xb = Join-Chemin $racineDisque 'XboxGames\Balatro'
        if (Test-Dossier $xb) { $XboxTrouve = $xb }
    }
} catch { }

if ($XboxTrouve) {
    Write-Ligne 'warn' "Version Xbox/Microsoft Store détectée ($XboxTrouve) : Steamodded et Lovely ne fonctionnent qu'avec la version Steam."
}

$Jeu = $null
if ($DossierJeu) {
    if (Test-Fichier (Join-Chemin $DossierJeu 'Balatro.exe')) { $Jeu = Get-CheminNormal $DossierJeu }
    else { Write-Ligne 'err' "Balatro.exe introuvable dans le dossier indiqué : $DossierJeu" }
} else {
    $steam = @($Candidats | Where-Object { $_.Manifeste })
    if ($steam.Count -ge 1) { $Jeu = ($steam | Sort-Object Date -Descending | Select-Object -First 1).Dossier }
    elseif ($Candidats.Count -eq 1) { $Jeu = $Candidats[0].Dossier }
    elseif ($Candidats.Count -gt 1) {
        Write-Host '     Plusieurs installations de Balatro ont été trouvées :'
        for ($i = 0; $i -lt $Candidats.Count; $i++) { Write-Host ("       {0}. {1}" -f ($i + 1), $Candidats[$i].Dossier) }
        $Jeu = ($Candidats | Sort-Object Date -Descending | Select-Object -First 1).Dossier
        $r = Wait-Entree "     Numéro de l'installation que vous lancez avec Steam (Entrée = $Jeu)"
        $n = 0
        if ([int]::TryParse($r, [ref]$n) -and $n -ge 1 -and $n -le $Candidats.Count) { $Jeu = $Candidats[$n - 1].Dossier }
    }
}
while (-not $Jeu -and -not $Oui -and -not $DiagnosticSeul) {
    Write-Host '     Balatro.exe introuvable automatiquement.'
    Write-Host '     Dans Steam : clic droit sur Balatro > Gérer > Parcourir les fichiers locaux,'
    Write-Host '     copiez l''adresse du dossier qui s''ouvre et collez-la ici.'
    $r = Read-Host '     Dossier du jeu (vide = abandonner)'
    if (-not $r) { break }
    $r = $r.Trim().Trim('"')
    if (Test-Fichier (Join-Chemin $r 'Balatro.exe')) { $Jeu = Get-CheminNormal $r } else { Write-Host "     Balatro.exe n'est pas dans ce dossier." }
}
if ($Jeu) {
    Write-Ligne 'ok' "Jeu : $Jeu"
    foreach ($x in $Candidats) {
        if (-not (Test-MemeChemin $x.Dossier $Jeu)) { Write-Ligne 'info' "Autre installation trouvée (pas celle utilisée) : $($x.Dossier)" }
    }
} else {
    Write-Ligne 'err' 'Dossier du jeu introuvable : Lovely ne peut pas être vérifié ni installé.'
}

# options de lancement Steam (--vanilla / -d désactivent Lovely)
foreach ($racine in $RacinesSteamTrouvees) {
    $ud = Join-Chemin $racine 'userdata'
    if (-not (Test-Dossier $ud)) { continue }
    foreach ($u in @(Get-ChildItem -LiteralPath $ud -Directory -ErrorAction SilentlyContinue)) {
        $lc = Join-Chemin (Join-Chemin $u.FullName 'config') 'localconfig.vdf'
        if (-not (Test-Fichier $lc)) { continue }
        $t = [string](Get-Content -LiteralPath $lc -Raw -ErrorAction SilentlyContinue)
        $pos = $t.IndexOf("`"$AppId`"")
        if ($pos -lt 0) { continue }
        $suite = $t.Substring($pos + $AppId.Length + 2)
        $mo = [regex]::Match($suite, '"LaunchOptions"\s+"([^"]*)"')
        $ma = [regex]::Match($suite, '(?m)^\s*"\d{3,}"\s*$')
        if ($mo.Success -and (-not $ma.Success -or $mo.Index -lt $ma.Index)) {
            $opts = $mo.Groups[1].Value
            if ($opts) {
                $jetons = $opts -split '\s+'
                if ($jetons -contains '--vanilla' -or $jetons -contains '-v' -or $jetons -contains '--disable-mods' -or $jetons -contains '-d') {
                    Write-Ligne 'err' "Les options de lancement Steam de Balatro désactivent les mods : « $opts ». Steam > clic droit Balatro > Propriétés > Général > Options de lancement : videz ce champ."
                } else { Write-Ligne 'info' "Options de lancement Steam de Balatro : « $opts »" }
            }
        }
    }
}

# ---------------------------------------------------------------------------------------------
# 2. Lovely
# ---------------------------------------------------------------------------------------------
Write-Ligne 'titre' '2. Lovely (winmm.dll dans le dossier du jeu)'

function Get-DossierTelechargements {
    if ($DossierTelechargements) { return $DossierTelechargements }
    try {
        $v = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name '{374DE290-123F-4565-9164-39C4925E467B}' -ErrorAction Stop).'{374DE290-123F-4565-9164-39C4925E467B}'
        if ($v) { return [System.Environment]::ExpandEnvironmentVariables($v) }
    } catch { }
    if ($env:USERPROFILE) { return (Join-Chemin $env:USERPROFILE 'Downloads') }
    return ''
}

function Find-SourcesLovely {
    # sources locales de winmm.dll : autre installation du jeu, paquet, Téléchargements, Bureau
    $res = New-Object System.Collections.Generic.List[object]
    foreach ($x in $Candidats) {
        if ($Jeu -and (Test-MemeChemin $x.Dossier $Jeu)) { continue }
        $w = Join-Chemin $x.Dossier 'winmm.dll'
        if ((Test-Fichier $w) -and (Test-EnTeteMZ $w)) {
            $res.Add([pscustomobject]@{ Genre = 'dll'; Chemin = $w; Entree = ''; Date = (Get-Item -LiteralPath $w).LastWriteTime; Libelle = "ancienne installation du jeu ($($x.Dossier))" })
        }
    }
    $dossiers = @($RacinePaquet, (Get-DossierTelechargements))
    try { $dossiers += [System.Environment]::GetFolderPath('Desktop') } catch { }
    foreach ($d in $dossiers) {
        if (-not (Test-Dossier $d)) { continue }
        foreach ($f in @(Get-ChildItem -LiteralPath $d -Filter 'lovely*.zip' -File -ErrorAction SilentlyContinue)) {
            try {
                Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
                $zip = [System.IO.Compression.ZipFile]::OpenRead($f.FullName)
                try {
                    foreach ($e in $zip.Entries) {
                        if ($e.Name -ieq 'winmm.dll') {
                            $res.Add([pscustomobject]@{ Genre = 'zip'; Chemin = $f.FullName; Entree = $e.FullName; Date = $f.LastWriteTime; Libelle = "archive $($f.Name)" })
                            break
                        }
                    }
                } finally { $zip.Dispose() }
            } catch { }
        }
        foreach ($f in @(Get-ChildItem -LiteralPath $d -Filter 'winmm.dll' -File -Recurse -Depth 2 -ErrorAction SilentlyContinue)) {
            if (Test-EnTeteMZ $f.FullName) {
                $res.Add([pscustomobject]@{ Genre = 'dll'; Chemin = $f.FullName; Entree = ''; Date = $f.LastWriteTime; Libelle = "fichier $($f.FullName)" })
            }
        }
    }
    return @($res | Sort-Object Date -Descending)
}

function Install-Lovely($source, [string]$dossierJeu) {
    $dest = Join-Chemin $dossierJeu 'winmm.dll'
    try {
        if ($source.Genre -eq 'zip') {
            Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
            $zip = [System.IO.Compression.ZipFile]::OpenRead($source.Chemin)
            try {
                $e = $zip.Entries | Where-Object { $_.FullName -eq $source.Entree } | Select-Object -First 1
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dest, $true)
            } finally { $zip.Dispose() }
        } else {
            Copy-Item -LiteralPath $source.Chemin -Destination $dest -Force -ErrorAction Stop
        }
    } catch {
        Write-Ligne 'err' "Copie de winmm.dll impossible : $($_.Exception.Message). Fermez le jeu, puis relancez INSTALLER_COPILOT.bat par clic droit > Exécuter en tant qu'administrateur."
        return $false
    }
    Start-Sleep -Seconds 3
    if (-not (Test-Fichier $dest)) {
        Write-Ligne 'err' "winmm.dll a disparu juste après la copie : l'antivirus l'a probablement supprimé. Ajoutez une exclusion pour le dossier du jeu ($dossierJeu) puis relancez."
        return $false
    }
    if (-not (Test-EnTeteMZ $dest)) { Write-Ligne 'err' 'Le winmm.dll copié n''est pas une DLL valide.'; return $false }
    Write-Ligne 'fait' "Lovely installé : $dest (depuis $($source.Libelle))"
    return $true
}

$LovelyOk = $false
if ($Jeu) {
    $winmm = Join-Chemin $Jeu 'winmm.dll'
    $anciens = @(@('version.dll', 'dwmapi.dll') | Where-Object { Test-Fichier (Join-Chemin $Jeu $_) })
    if ((Test-Fichier $winmm) -and -not (Test-EnTeteMZ $winmm)) {
        Write-Ligne 'err' "Le fichier $winmm n'est pas une DLL valide (fichier abîmé) : remplacez-le par celui de lovely-x86_64-pc-windows-msvc.zip."
    } elseif (Test-Fichier $winmm) {
        $LovelyOk = $true
        Write-Ligne 'ok' "Lovely présent : $winmm ($((Get-Item -LiteralPath $winmm).LastWriteTime.ToString('yyyy-MM-dd')))"
    } elseif ($anciens.Count -gt 0) {
        Write-Ligne 'warn' "Seule une ancienne version de Lovely est présente ($($anciens -join ', ')). Elle peut suffire ; les Steamodded récents demandent un Lovely récent (winmm.dll)."
        $LovelyOk = $true
        $sources = @(Find-SourcesLovely)
        if ($sources.Count -gt 0 -and (Read-Oui "     Installer le Lovely récent trouvé ($($sources[0].Libelle)) ?")) { $null = Install-Lovely $sources[0] $Jeu }
    } else {
        Write-Ligne 'warn' "Lovely est ABSENT du dossier du jeu : aucun mod ne peut se charger (cas typique après une réinstallation ou un déplacement du jeu)."
        $sources = @(Find-SourcesLovely)
        while (-not $LovelyOk) {
            if ($sources.Count -gt 0) {
                $s = $sources[0]
                Write-Ligne 'info' "winmm.dll disponible : $($s.Libelle)"
                if (Read-Oui "     Copier ce winmm.dll dans $Jeu ?") { $LovelyOk = Install-Lovely $s $Jeu }
                break
            }
            if ($Oui -or $DiagnosticSeul) { break }
            Write-Host ''
            Write-Host '     Pour installer Lovely, il faut son fichier officiel (rien n''est téléchargé automatiquement) :'
            Write-Host '       1. la page officielle va s''ouvrir : github.com/ethangreen-dev/lovely-injector/releases/latest'
            Write-Host '       2. téléchargez « lovely-x86_64-pc-windows-msvc.zip » (dans Téléchargements, sans l''ouvrir)'
            Write-Host '       3. revenez ici et appuyez sur Entrée.'
            Write-Host '     (Autre solution : le lanceur Balatro Multiplayer, balatromp.com, installe Lovely et Steamodded.)'
            if (Read-Oui '     Ouvrir la page de téléchargement officielle de Lovely ?') {
                if (-not (Open-Page 'https://github.com/ethangreen-dev/lovely-injector/releases/latest')) { Write-Host '     Ouvrez cette adresse dans votre navigateur : https://github.com/ethangreen-dev/lovely-injector/releases/latest' }
            }
            $r = Wait-Entree '     Appuyez sur Entrée quand le fichier est téléchargé (N = passer)'
            if ($r -eq 'n' -or $r -eq 'non') { break }
            $sources = @(Find-SourcesLovely)
            if ($sources.Count -eq 0) { Write-Host "     Aucun lovely*.zip trouvé dans $(Get-DossierTelechargements)." }
        }
        if (-not $LovelyOk) { Write-Ligne 'err' "Lovely n'est pas installé dans $Jeu : sans lui, aucun mod (ni Multiplayer, ni le copilote) ne se charge." }
        $anciens = @()
    }
    if ((Test-Fichier $winmm) -and $anciens.Count -gt 0) {
        foreach ($a in $anciens) {
            Write-Ligne 'warn' "Fichier d'une ancienne version de Lovely présent avec winmm.dll : $a (Lovely refuse alors de démarrer)."
            if (Read-Oui "     Renommer $a en $a.ancien-lovely (réversible) ?") {
                try {
                    Rename-Item -LiteralPath (Join-Chemin $Jeu $a) -NewName "$a.ancien-lovely" -ErrorAction Stop
                    Write-Ligne 'fait' "$a renommé en $a.ancien-lovely"
                } catch { Write-Ligne 'err' "Impossible de renommer $a : $($_.Exception.Message)" }
            } else { Write-Ligne 'err' "Supprimez ou renommez $(Join-Chemin $Jeu $a), sinon Lovely affiche « An old Lovely installation was detected » et le jeu ne démarre pas." }
        }
    }
}

# ---------------------------------------------------------------------------------------------
# 3. Dossier Mods et Steamodded
# ---------------------------------------------------------------------------------------------
Write-Ligne 'titre' '3. Dossier Mods et Steamodded'
$AppData = $DossierAppData
if (-not $AppData) { $AppData = $env:APPDATA }
if (-not $AppData) { Write-Ligne 'err' 'Variable APPDATA introuvable.'; $AppData = '' }
$DonneesBalatro = Join-Chemin $AppData 'Balatro'
$Mods = Join-Chemin $DonneesBalatro 'Mods'
$Sauvegardes = Join-Chemin (Join-Chemin $DonneesBalatro 'BSC_anciennes_copies') $Horodatage

if (-not (Test-Dossier $Mods)) {
    Write-Ligne 'warn' "Dossier Mods absent : $Mods"
    if (Read-Oui '     Créer le dossier Mods ?') {
        New-Item -ItemType Directory -Force -Path $Mods | Out-Null
        Write-Ligne 'fait' "Dossier créé : $Mods"
    }
} else { Write-Ligne 'ok' "Dossier Mods : $Mods" }

function Test-Steamodded([string]$d) {
    $man = Join-Chemin $d 'manifest.json'
    if (Test-Fichier $man) {
        try { if ((Get-Content -LiteralPath $man -Raw -Encoding UTF8 | ConvertFrom-Json).name -eq 'Steamodded') { return $true } } catch { }
    }
    return ((Test-Fichier (Join-Chemin $d 'version.lua')) -and (Test-Fichier (Join-Chemin (Join-Chemin $d 'src') 'core.lua')) -and (Test-Dossier (Join-Chemin $d 'lovely')))
}
function Get-VersionSteamodded([string]$d) {
    $t = [string](Get-Content -LiteralPath (Join-Chemin $d 'version.lua') -Raw -ErrorAction SilentlyContinue)
    $m = [regex]::Match($t, 'return\s+"([^"]+)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return '?'
}

$Smods = New-Object System.Collections.Generic.List[object]
$SmodsVersion = ''
if (Test-Dossier $Mods) {
    $liste = @()
    $lb = Join-Chemin (Join-Chemin $Mods 'lovely') 'blacklist.txt'
    if (Test-Fichier $lb) {
        $liste = @(Get-Content -LiteralPath $lb -ErrorAction SilentlyContinue | Where-Object { $_ -and -not $_.StartsWith('#') })
        if ($liste.Count -gt 0) { Write-Ligne 'warn' "Mods ignorés par Lovely (Mods\lovely\blacklist.txt) : $($liste -join ', ')" }
    }

    foreach ($d in @(Get-ChildItem -LiteralPath $Mods -Directory -ErrorAction SilentlyContinue)) {
        if ($d.Name -eq 'lovely') { continue }
        if (Test-Steamodded $d.FullName) {
            $Smods.Add([pscustomobject]@{ Dossier = $d.FullName; Version = (Get-VersionSteamodded $d.FullName); Date = $d.LastWriteTime; Imbrique = $false })
        } else {
            foreach ($s in @(Get-ChildItem -LiteralPath $d.FullName -Directory -ErrorAction SilentlyContinue)) {
                if (Test-Steamodded $s.FullName) {
                    $Smods.Add([pscustomobject]@{ Dossier = $s.FullName; Version = (Get-VersionSteamodded $s.FullName); Date = $s.LastWriteTime; Imbrique = $true })
                }
            }
        }
    }

    # Steamodded rangé un niveau trop bas : Lovely ne trouve pas ses patchs
    foreach ($s in @($Smods | Where-Object { $_.Imbrique })) {
        $parent = Split-Path -Parent $s.Dossier
        Write-Ligne 'warn' "Steamodded est rangé un niveau trop bas : $($s.Dossier) (il doit être directement dans Mods)."
        $cible = Join-Chemin $Mods (Split-Path -Leaf $s.Dossier)
        if (Test-Path -LiteralPath $cible) { $cible = Join-Chemin $Mods ((Split-Path -Leaf $s.Dossier) + '-steamodded') }
        if (Read-Oui "     Le déplacer vers $cible ?") {
            try {
                Move-Item -LiteralPath $s.Dossier -Destination $cible -ErrorAction Stop
                if (@(Get-ChildItem -LiteralPath $parent -Force -ErrorAction SilentlyContinue).Count -eq 0) { Remove-Item -LiteralPath $parent -ErrorAction SilentlyContinue }
                $s.Dossier = $cible; $s.Imbrique = $false
                Write-Ligne 'fait' "Steamodded déplacé : $cible"
            } catch { Write-Ligne 'err' "Déplacement impossible : $($_.Exception.Message)" }
        }
    }
    $SmodsBons = @($Smods | Where-Object { -not $_.Imbrique })

    # plusieurs copies de Steamodded : conflit
    if ($SmodsBons.Count -gt 1) {
        Write-Ligne 'warn' "Plusieurs copies de Steamodded dans Mods (une seule doit rester) :"
        for ($i = 0; $i -lt $SmodsBons.Count; $i++) { Write-Host ("       {0}. {1}  (version {2})" -f ($i + 1), $SmodsBons[$i].Dossier, $SmodsBons[$i].Version) }
        $garde = $SmodsBons | Sort-Object Date -Descending | Select-Object -First 1
        $r = Wait-Entree "     Numéro de la copie à GARDER (Entrée = $($garde.Dossier))"
        $n = 0
        if ([int]::TryParse($r, [ref]$n) -and $n -ge 1 -and $n -le $SmodsBons.Count) { $garde = $SmodsBons[$n - 1] }
        if (Read-Oui "     Déplacer les autres copies hors de Mods (dans $Sauvegardes) ?") {
            foreach ($s in $SmodsBons) {
                if ($s -eq $garde) { continue }
                try { $dest = Move-VersSauvegarde $s.Dossier $Sauvegardes; Write-Ligne 'fait' "Copie déplacée : $($s.Dossier) -> $dest" }
                catch { Write-Ligne 'err' "Déplacement impossible : $($_.Exception.Message)" }
            }
            $SmodsBons = @($garde)
        }
    }

    if ($SmodsBons.Count -ge 1) {
        $sm = $SmodsBons[0]
        $SmodsVersion = $sm.Version
        Write-Ligne 'ok' "Steamodded $($sm.Version) : $($sm.Dossier)"
        if (Test-Fichier (Join-Chemin $sm.Dossier '.lovelyignore')) {
            Write-Ligne 'warn' 'Steamodded est désactivé (fichier .lovelyignore).'
            if (Read-Oui '     Le réactiver (renommer .lovelyignore) ?') {
                Rename-Item -LiteralPath (Join-Chemin $sm.Dossier '.lovelyignore') -NewName ".lovelyignore.desactive-$Horodatage"
                Write-Ligne 'fait' 'Steamodded réactivé.'
            } else { Write-Ligne 'err' 'Steamodded est désactivé.' }
        }
        $nomSm = Split-Path -Leaf $sm.Dossier
        if ($liste -contains $nomSm) {
            Write-Ligne 'warn' "Steamodded est désactivé dans Mods\lovely\blacklist.txt (« $nomSm »)."
            if (-not ((Read-Oui "     Le réactiver (retirer « $nomSm » de la liste) ?") -and (Remove-ListeNoire $lb $nomSm))) {
                Write-Ligne 'err' "Steamodded est désactivé : retirez la ligne « $nomSm » de $lb."
            }
        }
    } else {
        $zipSm = @(Get-ChildItem -LiteralPath $Mods -Filter '*.zip' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)smods|steamodded' })
        if ($zipSm.Count -gt 0) {
            Write-Ligne 'warn' "Steamodded est présent seulement sous forme d'archive ($($zipSm[0].Name)) : les anciens Steamodded doivent être extraits."
        }
        Write-Ligne 'err' 'Steamodded est introuvable dans Mods.'
        $dl = Get-DossierTelechargements
        $cand = @()
        foreach ($d in @($RacinePaquet, $dl)) {
            if (Test-Dossier $d) { $cand += @(Get-ChildItem -LiteralPath $d -Filter '*.zip' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)^(smods|steamodded)' }) }
        }
        $cand = @($cand | Sort-Object LastWriteTime -Descending)
        if ($cand.Count -eq 0 -and -not $Oui -and -not $DiagnosticSeul) {
            Write-Host '     Pour installer Steamodded (rien n''est téléchargé automatiquement) :'
            Write-Host '       1. la page officielle va s''ouvrir : github.com/Steamodded/smods/releases/latest'
            Write-Host '       2. tout en bas, cliquez « Source code (zip) » (dans Téléchargements, sans l''ouvrir)'
            Write-Host '       3. revenez ici et appuyez sur Entrée.'
            if (Read-Oui '     Ouvrir la page de téléchargement officielle de Steamodded ?') {
                if (-not (Open-Page 'https://github.com/Steamodded/smods/releases/latest')) { Write-Host '     Adresse : https://github.com/Steamodded/smods/releases/latest' }
            }
            $r = Wait-Entree '     Appuyez sur Entrée quand le fichier est téléchargé (N = passer)'
            if ($r -ne 'n' -and $r -ne 'non' -and (Test-Dossier $dl)) {
                $cand = @(Get-ChildItem -LiteralPath $dl -Filter '*.zip' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)^(smods|steamodded)' } | Sort-Object LastWriteTime -Descending)
            }
        }
        if ($cand.Count -gt 0 -and (Read-Oui "     Installer Steamodded depuis $($cand[0].Name) ?")) {
            $tmp = Join-Chemin ([System.IO.Path]::GetTempPath()) "bsc_smods_$Horodatage"
            try {
                Expand-Archive -LiteralPath $cand[0].FullName -DestinationPath $tmp -Force -ErrorAction Stop
                $racineSm = $null
                if (Test-Steamodded $tmp) { $racineSm = $tmp }
                else { foreach ($s in @(Get-ChildItem -LiteralPath $tmp -Directory)) { if (Test-Steamodded $s.FullName) { $racineSm = $s.FullName; break } } }
                if (-not $racineSm) { throw "cette archive ne contient pas Steamodded" }
                $cible = Join-Chemin $Mods 'smods'
                if (Test-Path -LiteralPath $cible) { $cible = Join-Chemin $Mods "smods-$Horodatage" }
                Move-Item -LiteralPath $racineSm -Destination $cible -ErrorAction Stop
                $SmodsVersion = Get-VersionSteamodded $cible
                $Bloquants.Remove('Steamodded est introuvable dans Mods.') | Out-Null
                Write-Ligne 'fait' "Steamodded $SmodsVersion installé : $cible"
            } catch { Write-Ligne 'err' "Installation de Steamodded impossible : $($_.Exception.Message)" }
            finally { if (Test-Dossier $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } }
        }
    }

    # autres mods (information, utile pour le diagnostic)
    foreach ($d in @(Get-ChildItem -LiteralPath $Mods -Directory -ErrorAction SilentlyContinue)) {
        if ($d.Name -eq 'lovely') { continue }
        if (Test-Steamodded $d.FullName) { continue }
        $etat = ''
        if (Test-Fichier (Join-Chemin $d.FullName '.lovelyignore')) { $etat = ' (désactivé : .lovelyignore)' }
        $meta = @(Get-ChildItem -LiteralPath $d.FullName -Filter '*.json' -File -ErrorAction SilentlyContinue)
        $info = ''
        foreach ($f in $meta) {
            try {
                $j = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($j.id -and $j.main_file) { $info = " - mod $($j.id) $($j.version), dépend de : $(@($j.dependencies) -join ' ; ')"; break }
            } catch { }
        }
        Write-Ligne 'info' "Mod présent : $($d.Name)$etat$info"
    }
}

# ---------------------------------------------------------------------------------------------
# 4. Copilote
# ---------------------------------------------------------------------------------------------
Write-Ligne 'titre' '4. Balatro Strategic Copilot'
$Cible = Join-Chemin $Mods 'BalatroStrategicCopilot'
$CopilotePret = $false
if (Test-Dossier $Mods) {
    $copies = @(Get-ChildItem -LiteralPath $Mods -Recurse -Depth 6 -Filter 'BalatroStrategicCopilot.json' -File -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-SousChemin $_.FullName (Join-Chemin $Mods 'lovely')) })
    $zips = @(Get-ChildItem -LiteralPath $Mods -Filter 'BalatroStrategicCopilot*.zip' -File -ErrorAction SilentlyContinue)
    foreach ($c in $copies) { Write-Ligne 'info' "Copie trouvée : $($c.FullName)" }
    foreach ($z in $zips) { Write-Ligne 'warn' "Archive du copilote déposée telle quelle (ignorée par les anciens Steamodded) : $($z.FullName)" }

    $dejaBon = ($copies.Count -eq 1 -and $zips.Count -eq 0 -and (Test-MemeChemin (Split-Path -Parent $copies[0].FullName) $Cible))
    if ($dejaBon -and $SourceMod) {
        try {
            $installe = [string](Get-Content -LiteralPath $copies[0].FullName -Raw -Encoding UTF8 | ConvertFrom-Json).version
            if ($installe -ne $VersionPaquet) { $dejaBon = $false }
        } catch { $dejaBon = $false }
    }
    if ($SourceMod -and (Test-MemeChemin $SourceMod $Cible)) { $dejaBon = $true }

    if ($dejaBon) {
        Write-Ligne 'ok' "Copilote déjà installé au bon endroit : $Cible"
        $CopilotePret = $true
    } elseif ($SourceMod) {
        $msg = "     Installer le copilote $VersionPaquet dans $Cible"
        if ($copies.Count -gt 0 -or $zips.Count -gt 0) { $msg += " (les anciennes copies seront DÉPLACÉES dans $Sauvegardes, rien n'est supprimé)" }
        if (Read-Oui "$msg ?") {
            $ok = $true
            # source à l'abri si le paquet a été extrait dans Mods
            $src = $SourceMod
            if (Test-SousChemin $SourceMod $Mods) {
                Write-Ligne 'warn' "Le paquet a été extrait DANS Mods ($RacinePaquet) : après l'installation, sortez ce dossier de Mods."

                $src = Join-Chemin ([System.IO.Path]::GetTempPath()) "bsc_copilote_$Horodatage"
                Copy-Item -LiteralPath $SourceMod -Destination $src -Recurse -Force
            }
            $aDeplacer = New-Object System.Collections.Generic.List[string]
            foreach ($c in $copies) {
                $dossierCopie = Split-Path -Parent $c.FullName
                $haut = $dossierCopie
                while ((Split-Path -Parent $haut) -and -not (Test-MemeChemin (Split-Path -Parent $haut) $Mods)) { $haut = Split-Path -Parent $haut }
                $choix = $dossierCopie
                if (-not (Test-MemeChemin $haut $dossierCopie) -and -not (Test-SousChemin $DossierScript $haut)) {
                    # dossier englobant (ex. dépôt GitHub entier) : on le déplace s'il ne contient pas d'autre mod
                    $autres = @(Get-ChildItem -LiteralPath $haut -Recurse -Depth 3 -Filter '*.json' -File -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -ne 'BalatroStrategicCopilot.json' })
                    if ($autres.Count -eq 0 -and -not (Test-Dossier (Join-Chemin $haut 'lovely'))) { $choix = $haut }
                }
                if (-not ($aDeplacer | Where-Object { Test-MemeChemin $_ $choix })) { $aDeplacer.Add($choix) }
            }
            foreach ($z in $zips) { $aDeplacer.Add($z.FullName) }
            foreach ($p in $aDeplacer) {
                if (-not (Test-Path -LiteralPath $p)) { continue }
                try { $dest = Move-VersSauvegarde $p $Sauvegardes; Write-Ligne 'fait' "Ancienne copie déplacée : $p -> $dest" }
                catch { Write-Ligne 'err' "Impossible de déplacer $p : $($_.Exception.Message)"; $ok = $false }
            }
            if ($ok -and (Test-Path -LiteralPath $Cible)) { Write-Ligne 'err' "$Cible existe encore : installation interrompue."; $ok = $false }
            if ($ok) {
                try {
                    Copy-Item -LiteralPath $src -Destination $Cible -Recurse -Force -ErrorAction Stop
                    $manque = 0
                    foreach ($f in @(Get-ChildItem -LiteralPath $src -Recurse -File)) {
                        $rel = $f.FullName.Substring((Get-CheminNormal $src).Length).TrimStart('\', '/')
                        $g = Join-Chemin $Cible $rel
                        if (-not (Test-Fichier $g) -or (Get-Item -LiteralPath $g).Length -ne $f.Length) { $manque++ }
                    }
                    if ($manque -gt 0) { Write-Ligne 'err' "$manque fichier(s) mal copiés dans $Cible." }
                    else {
                        Write-Ligne 'fait' "Copilote $VersionPaquet installé : $Cible"
                        $CopilotePret = $true
                    }
                } catch { Write-Ligne 'err' "Copie impossible : $($_.Exception.Message)" }
            }
            if (-not (Test-MemeChemin $src $SourceMod)) { Remove-Item -LiteralPath $src -Recurse -Force -ErrorAction SilentlyContinue }
        } else {
            if ($copies.Count -eq 0) { Write-Ligne 'err' 'Le copilote n''est pas installé.' }
            else { Write-Ligne 'warn' 'Le copilote n''a pas été (ré)installé.' }
        }
    } else {
        if ($copies.Count -eq 0) { Write-Ligne 'err' 'Le copilote n''est pas installé.' }
    }
    if (Test-Fichier (Join-Chemin $Cible 'BalatroStrategicCopilot.json')) {
        if (Test-Fichier (Join-Chemin $Cible '.lovelyignore')) {
            Write-Ligne 'warn' 'Le copilote est désactivé (fichier .lovelyignore).'
            if (Read-Oui '     Le réactiver ?') { Rename-Item -LiteralPath (Join-Chemin $Cible '.lovelyignore') -NewName ".lovelyignore.desactive-$Horodatage"; Write-Ligne 'fait' 'Copilote réactivé.' }
        }
        $lb = Join-Chemin (Join-Chemin $Mods 'lovely') 'blacklist.txt'
        if ((Test-Fichier $lb) -and (@(Get-Content -LiteralPath $lb -ErrorAction SilentlyContinue | ForEach-Object { $_.Trim() }) -contains 'BalatroStrategicCopilot')) {
            Write-Ligne 'warn' 'Le copilote est désactivé dans le menu Mods (Mods\lovely\blacklist.txt).'
            if (-not ((Read-Oui '     Le réactiver ?') -and (Remove-ListeNoire $lb 'BalatroStrategicCopilot'))) {
                Write-Ligne 'err' "Le copilote est désactivé : réactivez-le dans le menu Mods du jeu, ou retirez la ligne « BalatroStrategicCopilot » de $lb."
            }
        }
        $restantes = @(Get-ChildItem -LiteralPath $Mods -Recurse -Depth 6 -Filter 'BalatroStrategicCopilot.json' -File -ErrorAction SilentlyContinue |
            Where-Object { -not (Test-SousChemin $_.FullName (Join-Chemin $Mods 'lovely')) })
        if ($restantes.Count -gt 1) { Write-Ligne 'warn' "Il reste $($restantes.Count) copies du copilote dans Mods : n'en gardez qu'une ($Cible)." }
        if ($restantes.Count -ge 1) { $CopilotePret = $true; Write-Ligne 'ok' "Emplacement correct : $(Join-Chemin $Cible 'BalatroStrategicCopilot.json')" }
    }
}

# ---------------------------------------------------------------------------------------------
# 5. Journal de Lovely : ce qui s'est réellement passé au dernier lancement
# ---------------------------------------------------------------------------------------------
$DossierLogs = Join-Chemin (Join-Chemin $Mods 'lovely') 'log'

function Get-DernierLog([datetime]$depuis) {
    if (-not (Test-Dossier $DossierLogs)) { return $null }
    $f = Get-ChildItem -LiteralPath $DossierLogs -Filter 'lovely-*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.CreationTime -ge $depuis -or $_.LastWriteTime -ge $depuis } |
        Sort-Object @{ Expression = { if ($_.CreationTime -gt $_.LastWriteTime) { $_.CreationTime } else { $_.LastWriteTime } } } -Descending |
        Select-Object -First 1
    return $f
}

function Get-AnalyseLog([string]$chemin) {
    $a = [pscustomobject]@{ Chemin = $chemin; Lovely = ''; JeuLog = ''; ModsLog = ''; Vanilla = $false; Patchs = 0
        Steamodded = ''; Pret = ''; ErreurCopilote = ''; Plantage = ''; Lignes = (New-Object System.Collections.Generic.List[string]) }
    $texte = ''
    try { $texte = Read-Partage $chemin } catch { return $a }
    $lignes = $texte -split "`r?`n"
    for ($i = 0; $i -lt $lignes.Count; $i++) {
        $l = $lignes[$i]
        if (-not $a.Lovely -and $l -match '\] Lovely (\S+)') { $a.Lovely = $Matches[1] }
        if ($l -match 'Game directory is at "?(.+?)"?$') { $a.JeuLog = $Matches[1] -replace '\\\\', '\' }
        if ($l -match 'Using mod directory at "?(.+?)"?$') { $a.ModsLog = $Matches[1] -replace '\\\\', '\' }
        if ($l -match 'Running in vanilla mode') { $a.Vanilla = $true }
        if ($l -match 'Applied (\d+) patch') { $a.Patchs += [int]$Matches[1] }
        if (-not $a.Steamodded -and $l -match 'Steamodded v(\S+)') { $a.Steamodded = $Matches[1] }
        if ($l -match ':: BSCopilot ::' -or $l -match 'BalatroStrategicCopilot' -or $l -match 'Strategic Copilot') {
            $a.Lignes.Add($l.Trim())
            if ($l -match 'ready \(') { $a.Pret = $l.Trim() }
            if ($l -match 'failed to start') {
                $bloc = $l.Trim()
                for ($k = $i + 1; $k -lt [Math]::Min($i + 6, $lignes.Count); $k++) { if ($lignes[$k] -match '^\s*(INFO|WARN|ERROR|DEBUG) - ') { break }; $bloc += ' | ' + $lignes[$k].Trim() }
                $a.ErreurCopilote = $bloc
            }
        } elseif ($l -match 'invalid metadata|unable to load|Missing Dependencies|Unresolved Conflicts|Duplicate Mod') {
            $a.Lignes.Add($l.Trim())
        }
        if (-not $a.Plantage -and $l -match 'Oops! The game crashed') {
            $bloc = $l.Trim()
            for ($k = $i + 1; $k -lt [Math]::Min($i + 8, $lignes.Count); $k++) { $bloc += ' | ' + $lignes[$k].Trim() }
            $a.Plantage = $bloc
        }
    }
    return $a
}

function Show-AnalyseLog($a, [bool]$ancien) {
    # journal antérieur aux corrections faites à l'instant : ses erreurs ne sont plus forcément vraies
    $e = 'err'
    if ($ancien) { $e = 'warn'; Write-Ligne 'info' 'Ce journal date d''AVANT les corrections ci-dessus : lancez le jeu pour vérifier.' }
    Write-Ligne 'info' "Journal : $($a.Chemin)"
    if ($a.Lovely) { Write-Ligne 'ok' "Lovely $($a.Lovely) a démarré avec le jeu." } else { Write-Ligne 'warn' 'Version de Lovely absente du journal.' }
    if ($a.JeuLog) { Write-Ligne 'info' "Jeu lancé depuis : $($a.JeuLog)" }
    if ($a.ModsLog) {
        if ($Mods -and -not (Test-MemeChemin $a.ModsLog $Mods)) {
            Write-Ligne $e "Lovely utilise un AUTRE dossier Mods : $($a.ModsLog) (au lieu de $Mods). Le copilote doit être dans ce dossier-là."
        } else { Write-Ligne 'ok' "Dossier Mods utilisé par Lovely : $($a.ModsLog)" }
    }
    if ($a.Vanilla) { Write-Ligne $e 'Le jeu a été lancé en mode « vanilla » (mods désactivés) : retirez --vanilla des options de lancement Steam.' }
    if ($a.Steamodded) { Write-Ligne 'ok' "Steamodded $($a.Steamodded) chargé ($($a.Patchs) modifications appliquées par Lovely)." }
    elseif (-not $a.Vanilla) { Write-Ligne $e "Steamodded ne s'est pas chargé ($($a.Patchs) modifications appliquées par Lovely) : vérifiez qu'il est directement dans Mods (Mods\smods\lovely\...)." }
    foreach ($l in $a.Lignes) { Write-Ligne 'info' "  > $l" }
    if ($a.Pret) { Write-Ligne 'ok' 'Le copilote a démarré : le bandeau vert doit être visible en haut de l''écran.' }
    elseif ($a.ErreurCopilote) { Write-Ligne $e "Le copilote a rencontré une erreur au démarrage : $($a.ErreurCopilote)" }
    elseif ($a.Steamodded) { Write-Ligne $e 'Steamodded est chargé mais le copilote n''apparaît pas dans le journal : il n''a pas été trouvé dans Mods.' }
    if ($a.Plantage) { Write-Ligne $e "Le jeu a planté : $($a.Plantage)" }
}

$AnalyseFaite = $false
$Pret = ($Bloquants.Count -eq 0 -and $Jeu -and $LovelyOk -and $CopilotePret)
if (-not $DiagnosticSeul -and -not $SansLancement -and $Jeu) {
    Write-Ligne 'titre' '5. Vérification en lançant le jeu'
    if (-not $Pret) { Write-Ligne 'warn' 'Des problèmes restent signalés ci-dessus : le test de lancement dira lequel bloque réellement.' }
    if (Read-Oui '     Lancer Balatro maintenant (via Steam) pour vérifier que tout se charge ?') {
        $lancement = (Get-Date).AddSeconds(-2)
        if (-not (Open-Page "steam://rungameid/$AppId")) { Write-Ligne 'warn' 'Steam n''a pas pu être lancé automatiquement : lancez Balatro vous-même.' }
        Write-Host "     Attente du jeu (jusqu'à $AttenteSecondes s). Laissez le jeu arriver au menu principal..." -NoNewline
        $limite = (Get-Date).AddSeconds($AttenteSecondes)
        $log = $null; $analyse = $null; $proc = $null
        $taille = -1; $calmeDepuis = Get-Date; $vuDepuis = $null
        while ((Get-Date) -lt $limite) {
            Start-Sleep -Seconds 2
            Write-Host '.' -NoNewline
            if (-not $proc) { $proc = Get-Process -Name 'Balatro' -ErrorAction SilentlyContinue | Select-Object -First 1 }
            $log = Get-DernierLog $lancement
            if ($log) {
                if (-not $vuDepuis) { $vuDepuis = Get-Date }
                $analyse = Get-AnalyseLog $log.FullName
                if ($analyse.Pret -or $analyse.ErreurCopilote -or $analyse.Plantage) { break }
                $t = 0
                try { $t = (Read-Partage $log.FullName).Length } catch { }
                if ($t -ne $taille) { $taille = $t; $calmeDepuis = Get-Date }
                # journal immobile depuis 30 s et jeu lancé depuis au moins 45 s : le chargement est fini
                if (((Get-Date) - $calmeDepuis).TotalSeconds -ge 30 -and ((Get-Date) - $vuDepuis).TotalSeconds -ge 45) { break }
            }
        }
        Write-Host ''
        $AnalyseFaite = $true
        if ($proc) {
            $exe = ''
            try { $exe = $proc.Path } catch { }
            if ($exe) {
                $dossierExe = Split-Path -Parent $exe
                if (-not (Test-MemeChemin $dossierExe $Jeu)) {
                    Write-Ligne 'err' "Steam a lancé Balatro depuis $dossierExe, mais la vérification portait sur $Jeu. Relancez ce programme : il proposera d'installer Lovely au bon endroit."
                } else { Write-Ligne 'ok' "Balatro lancé depuis $dossierExe" }
            }
        }
        if ($log) { Show-AnalyseLog $analyse $false }
        elseif ($proc) {
            $w = Join-Chemin $Jeu 'winmm.dll'
            if (-not (Test-Fichier $w)) { Write-Ligne 'err' 'Le jeu tourne SANS Lovely : winmm.dll a disparu du dossier du jeu (antivirus ?). Ajoutez une exclusion pour ce dossier et relancez ce programme.' }
            else { Write-Ligne 'err' 'Le jeu tourne mais Lovely n''a écrit aucun journal : la fenêtre noire « Lovely » est-elle apparue ? Vérifiez les options de lancement Steam (pas de --vanilla ni -d) et que le winmm.dll vient bien de lovely-x86_64-pc-windows-msvc.zip.' }
        } else {
            Write-Ligne 'warn' "Le jeu n'a pas été détecté. Lancez Balatro vous-même puis, une fois au menu, double-cliquez sur DIAGNOSTIC_COPILOT.bat."
        }
    }
}
if (-not $AnalyseFaite) {
    Write-Ligne 'titre' '5. Dernier lancement du jeu (journal de Lovely)'
    $dernier = Get-DernierLog ([datetime]::MinValue)
    if ($dernier) {
        Write-Ligne 'info' "Dernier journal : $($dernier.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        $ancien = ($script:Modifs -gt 0)
        if ($Jeu) {
            $exeDate = (Get-Item -LiteralPath (Join-Chemin $Jeu 'Balatro.exe')).LastWriteTime
            if ($dernier.LastWriteTime -lt $exeDate) {
                Write-Ligne 'warn' 'Ce journal est plus ancien que l''installation actuelle du jeu : depuis, Lovely ne s''est pas lancé avec ce jeu.'
                $ancien = $true
            }
        }
        Show-AnalyseLog (Get-AnalyseLog $dernier.FullName) $ancien
    } else {
        Write-Ligne 'warn' "Aucun journal de Lovely dans $DossierLogs : Lovely ne s'est jamais lancé avec ce dossier Mods."
    }
}

# ---------------------------------------------------------------------------------------------
# Bilan et rapport
# ---------------------------------------------------------------------------------------------
Write-Ligne 'titre' 'Bilan'
if ($Bloquants.Count -eq 0) {
    Write-Ligne 'ok' 'Aucun problème bloquant détecté.'
    Write-Ligne 'info' 'Au lancement : fenêtre noire « Lovely », bouton Mods au menu, bandeau vert « Balatro Strategic Copilot … actif ».'
    Write-Ligne 'info' 'En partie : résumé en haut à droite, touche C = panneau complet.'
} else {
    Write-Ligne 'info' "$($Bloquants.Count) problème(s) bloquant(s) :"
    foreach ($b in $Bloquants) { Write-Host "       - $b" -ForegroundColor Red; $Journal.Add("       - $b") }
}

if (-not $Rapport) {
    $bureau = ''
    try { $bureau = [System.Environment]::GetFolderPath('Desktop') } catch { }
    if (-not (Test-Dossier $bureau)) { $bureau = $DossierScript }
    $Rapport = Join-Chemin $bureau 'Rapport_Copilot_Balatro.txt'
}
try {
    $Journal.Add('')
    $Journal.Add('(Ce rapport contient les chemins de vos dossiers, donc votre nom d''utilisateur Windows. Rien d''autre.)')
    [System.IO.File]::WriteAllLines($Rapport, $Journal, (New-Object System.Text.UTF8Encoding($true)))
    Write-Host ''
    Write-Host "Rapport enregistré : $Rapport" -ForegroundColor Cyan
    Write-Host 'Si quelque chose ne marche pas, envoyez ce fichier.' -ForegroundColor Cyan
    if (-not $Oui -and -not $DiagnosticSeul) {
        if (Read-Oui '     Ouvrir le rapport ?') { try { Start-Process notepad.exe -ArgumentList "`"$Rapport`"" | Out-Null } catch { } }
    }
} catch { Write-Host "Rapport non enregistré : $($_.Exception.Message)" -ForegroundColor Yellow }

if ($Bloquants.Count -gt 0) { exit 1 }
exit 0
