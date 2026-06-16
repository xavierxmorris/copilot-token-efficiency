<#
.SYNOPSIS
  Audit your Copilot CLI config for token-waste and print prioritized fixes (read-only).

.EXAMPLE
  ./audit-config.ps1
#>
[CmdletBinding()]
param(
    [string]$CopilotDir = (Join-Path $env:USERPROFILE '.copilot')
)

$ErrorActionPreference = 'Stop'

function Read-Json($path) {
    if (Test-Path $path) { return Get-Content $path -Raw | ConvertFrom-Json }
    return $null
}

$settings = Read-Json (Join-Path $CopilotDir 'settings.json')
$mcp      = Read-Json (Join-Path $CopilotDir 'mcp-config.json')

$findings = New-Object System.Collections.Generic.List[object]
function Add-Finding($sev, $msg, $fix) {
    $findings.Add([pscustomobject]@{ Severity = $sev; Finding = $msg; Fix = $fix })
}

# 1. High default effort
if ($settings.effortLevel -in @('xhigh', 'max')) {
    Add-Finding 'HIGH' "Default effort is '$($settings.effortLevel)' — max reasoning tokens on every turn." `
        "Use lean profile (effort=medium) for routine work; switch up on demand."
}

# 2. Top-tier default model
if ($settings.model -like '*opus*') {
    Add-Finding 'MEDIUM' "Default model is '$($settings.model)' (top tier) for ALL turns." `
        "Consider claude-sonnet-4.6 / gpt-5.5 as the everyday default; reserve Opus for hard tasks."
}

# 3. MCP servers without allowlist
if ($mcp.mcpServers) {
    foreach ($p in $mcp.mcpServers.PSObject.Properties) {
        $srv = $p.Value
        if ($srv -isnot [psobject]) { continue }
        if (-not $srv.tools) {
            Add-Finding 'MEDIUM' "MCP server '$($p.Name)' loads ALL its tools every turn (no allowlist)." `
                "Add a 'tools' array to load only what you use, or disable via /mcp when unused."
        }
    }
}

# 4. No per-subagent routing
if (-not $settings.subagents.agents) {
    Add-Finding 'LOW' "No explicit per-subagent model routing set." `
        "Set subagents.agents.<name> to route heavy work to GPT-5.5 and keep explore/task cheap."
}

# Report
Write-Host "`n=== Copilot CLI config audit ===" -ForegroundColor Cyan
if ($findings.Count -eq 0) {
    Write-Host "No token-waste issues found. Nice." -ForegroundColor Green
} else {
    $order = @{ HIGH = 0; MEDIUM = 1; LOW = 2 }
    $findings |
        Sort-Object @{ Expression = { $order[$_.Severity] } } |
        Format-Table -AutoSize -Wrap
    Write-Host "Apply a profile with: ./switch-profile.ps1 lean   (or power)" -ForegroundColor DarkGray
}
