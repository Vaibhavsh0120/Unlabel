param(
    [ValidateSet('local', 'production')][string]$Mode,
    [ValidateSet('all', 'backend', 'frontend')][string]$Scope,
    [ValidateRange(1,65535)][int]$BackendPort,
    [ValidateRange(1,65535)][int]$WebPort,
    [string]$BackendUrl
)
$ErrorActionPreference = 'Stop'
$arguments = @((Join-Path $PSScriptRoot 'run_local.py'))
if ($Mode) { $arguments += @('--mode', $Mode) }
if ($Scope) { $arguments += @('--scope', $Scope) }
if ($PSBoundParameters.ContainsKey('BackendPort')) { $arguments += @('--backend-port', "$BackendPort") }
if ($PSBoundParameters.ContainsKey('WebPort')) { $arguments += @('--web-port', "$WebPort") }
if ($BackendUrl) { $arguments += @('--backend-url', $BackendUrl) }
if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 @arguments
} else {
    & python @arguments
}
exit $LASTEXITCODE
