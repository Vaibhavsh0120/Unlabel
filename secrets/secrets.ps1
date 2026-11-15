# Run from the repository root: .\secrets\secrets.ps1 encrypt | decrypt | verify | status
[CmdletBinding()]
param(
    [ValidateSet('encrypt', 'decrypt', 'verify', 'status', '1', '2', '3', '4')]
    [string]$Command,
    [string]$Recipient,
    [string]$Identity,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$selection = $Command
if (-not $selection) {
    Write-Host '1. Encrypt and refresh the Git-safe backup'
    Write-Host '2. Decrypt and restore files to their original paths'
    Write-Host '3. Verify local files against the encrypted backup'
    Write-Host '4. Show backup status'
    Write-Host '0. Back'
    $selection = Read-Host 'Choose an action'
    if ($null -eq $selection -or $selection.Trim() -eq '0') { exit 0 }
    $selection = $selection.Trim()
}
$choices = @{ '1' = 'encrypt'; '2' = 'decrypt'; '3' = 'verify'; '4' = 'status' }
if ($choices.ContainsKey($selection)) { $selection = $choices[$selection] }
if ($selection -notin @('encrypt', 'decrypt', 'verify', 'status')) {
    throw 'Choose 1, 2, 3, 4, encrypt, decrypt, verify or status.'
}
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$toolArguments = @((Join-Path $repositoryRoot 'scripts/project_secrets.py'), $selection)
if ($selection -eq 'encrypt') {
    # Use the actual agel function from the user's PowerShell profile.
    $toolArguments += '--agel'
    if ($Recipient) { $toolArguments += @('--recipient', $Recipient) }
} elseif ($selection -in @('decrypt', 'verify')) {
    if ($Identity) { $toolArguments += @('--identity', $Identity) }
    else { $toolArguments += '--paste-key' }
    if ($Force -and $selection -eq 'decrypt') { $toolArguments += '--force' }
}
& python @toolArguments
if ($LASTEXITCODE -ne 0) { throw 'Secret operation failed; see the safe error above.' }
