param(
    [ValidateSet('local', 'lan', 'production')][string]$Mode,
    [string]$LanIp,
    [ValidateRange(1,65535)][int]$HttpsPort,
    [ValidateSet('all', 'backend', 'frontend')][string]$Scope,
    [ValidateRange(1,65535)][int]$BackendPort,
    [ValidateRange(1,65535)][int]$WebPort,
    [string]$BackendUrl
)
$ErrorActionPreference = 'Stop'
$arguments = @((Join-Path $PSScriptRoot 'run_local.py'))
if ($Mode) { $arguments += @('--mode', $Mode) }
if ($LanIp) { $arguments += @('--lan-ip', $LanIp) }
if ($PSBoundParameters.ContainsKey('HttpsPort')) { $arguments += @('--https-port', "$HttpsPort") }
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
