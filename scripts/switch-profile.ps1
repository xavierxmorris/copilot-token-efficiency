<#
.SYNOPSIS
  Switch your GitHub Copilot CLI between the 'lean' and 'power' token profiles.

.DESCRIPTION
  Merges examples/settings.<profile>.json into your live ~/.copilot/settings.json.
  Your current settings.json is backed up first. Only the token-relevant keys
  (model, effortLevel, contextTier, subagents) are changed; everything else
  (allowedUrls, plugins, voice, etc.) is preserved.

.EXAMPLE
  ./switch-profile.ps1 lean
  ./switch-profile.ps1 power
  ./switch-profile.ps1 power -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('lean', 'power')]
    [string]$Profile,

    [string]$CopilotDir = (Join-Path $env:USERPROFILE '.copilot')
)

$ErrorActionPreference = 'Stop'
$repoRoot    = Split-Path -Parent $PSScriptRoot
$profilePath = Join-Path $repoRoot "examples\settings.$Profile.json"
$livePath    = Join-Path $CopilotDir 'settings.json'

if (-not (Test-Path $profilePath)) { throw "Profile file not found: $profilePath" }
if (-not (Test-Path $livePath))    { throw "Live settings not found: $livePath" }

$profileObj = Get-Content $profilePath -Raw | ConvertFrom-Json
$liveObj    = Get-Content $livePath -Raw | ConvertFrom-Json

# Backup (skipped on -WhatIf)
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = "$livePath.bak-$stamp"
if (-not $WhatIfPreference) {
    Copy-Item $livePath $backup
    Write-Host "Backed up live settings -> $backup" -ForegroundColor DarkGray
}

# Merge only non-comment keys (skip any property whose name starts with '//')
$changed = @()
foreach ($prop in $profileObj.PSObject.Properties) {
    if ($prop.Name.StartsWith('//')) { continue }
    $changed += $prop.Name
    if ($PSCmdlet.ShouldProcess($livePath, "Set '$($prop.Name)'")) {
        $liveObj | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
    }
}

if ($PSCmdlet.ShouldProcess($livePath, 'Write merged settings')) {
    $liveObj | ConvertTo-Json -Depth 20 | Set-Content $livePath -Encoding UTF8
    Write-Host "Applied '$Profile' profile. Keys changed: $($changed -join ', ')" -ForegroundColor Green
    Write-Host "Restart the CLI (/restart) for model/effort changes to take effect." -ForegroundColor Yellow
} else {
    Write-Host "[WhatIf] Would set: $($changed -join ', ')" -ForegroundColor Cyan
}
