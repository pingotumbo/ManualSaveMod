# sync_to_workshop.ps1
# Copies all mod files from the dev repo to the Workshop folder that PZ loads.
# Run this before launching PZ to test changes.

$src = "C:\Users\paolo\Zomboid\mods\ManualSaveMod"
$dst = "C:\Users\paolo\Zomboid\Workshop\ManualSaveMod\Contents\mods\ManualSaveMod"

if (-not (Test-Path $dst)) { Write-Error "Workshop path not found: $dst"; exit 1 }

$items = @(
    "common",
    "mod.info",
    "ManualSave_Watcher.ps1"
)

foreach ($item in $items) {
    $s = Join-Path $src $item
    $d = Join-Path $dst $item
    if (Test-Path $s -PathType Container) {
        Copy-Item -Path $s -Destination $d -Recurse -Force
    } elseif (Test-Path $s) {
        Copy-Item -Path $s -Destination $d -Force
    }
    Write-Host "synced: $item"
}

Write-Host "`nDone. Restart PZ to load changes."
