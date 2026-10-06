param(
    [ValidateSet('all', 'backend', 'frontend')][string]$Scope = 'all',
    [string]$Identity,
    [switch]$NonInteractive,
    [switch]$ReplaceCatalogue
)
$ErrorActionPreference = 'Stop'
$arguments = @((Join-Path $PSScriptRoot 'setup.py'), '--scope', $Scope)
if ($Identity) { $arguments += @('--identity', $Identity) }
if ($NonInteractive) { $arguments += '--non-interactive' }
if ($ReplaceCatalogue) { $arguments += '--replace-catalogue' }
if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 @arguments
} else {
    & python @arguments
}
exit $LASTEXITCODE
