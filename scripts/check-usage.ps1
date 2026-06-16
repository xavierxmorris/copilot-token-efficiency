<#
.SYNOPSIS
  Show the current token-cost posture of your Copilot CLI config (read-only).

.DESCRIPTION
  A quick "what am I paying for" dashboard: effective model + effort, per-subagent
  routing, and how many MCP servers/tools load into context every turn. Does not
  change anything. For live in-session token usage, use /context and /usage in the CLI.

.EXAMPLE
  ./check-usage.ps1
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

Write-Host "`n=== Copilot CLI token posture ===" -ForegroundColor Cyan

# Main agent
$model  = if ($settings.model)       { $settings.model }       else { '(default)' }
$effort = if ($settings.effortLevel) { $settings.effortLevel } else { '(default)' }
$tier   = if ($settings.contextTier) { $settings.contextTier } else { 'default' }
Write-Host ("Main agent : {0}  effort={1}  contextTier={2}" -f $model, $effort, $tier)

$heavy = ($effort -in @('xhigh', 'max'))
if ($heavy) {
    Write-Host "  -> High effort = heavy reasoning tokens on EVERY turn. Consider the lean profile for routine work." -ForegroundColor Yellow
}

# Subagents
Write-Host "`nSubagents :" -ForegroundColor Cyan
if ($settings.subagents.agents) {
    foreach ($p in $settings.subagents.agents.PSObject.Properties) {
        $a = $p.Value
        Write-Host ("  {0,-16} model={1}  effort={2}" -f $p.Name, $a.model, $a.effortLevel)
    }
} else {
    Write-Host "  (none set — using experiment defaults: explore=GPT-5.4-mini, task/general=GPT-5.4)"
}

# MCP tool surface
Write-Host "`nMCP servers (tool defs load every turn):" -ForegroundColor Cyan
if ($mcp.mcpServers) {
    $total = 0
    foreach ($p in $mcp.mcpServers.PSObject.Properties) {
        $srv = $p.Value
        if ($srv -isnot [psobject]) { continue }
        $tools = if ($srv.tools) { $srv.tools.Count } else { $null }
        $label = if ($null -ne $tools) { "$tools tool(s) [allowlisted]"; $total += $tools } else { 'ALL tools [not allowlisted]' }
        Write-Host ("  {0,-16} {1}" -f $p.Name, $label)
    }
    Write-Host "  -> Servers without an allowlist load all their tools. Trim with /mcp or a 'tools' array." -ForegroundColor DarkGray
} else {
    Write-Host "  (no MCP servers configured)"
}

Write-Host "`nFor live token usage this session, run /context and /usage in the CLI.`n" -ForegroundColor DarkGray
