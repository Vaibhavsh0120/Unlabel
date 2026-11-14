# Run from any directory: .\secrets.ps1 encrypt | decrypt | verify | status
[CmdletBinding()]
param(
    [ValidateSet('encrypt', 'decrypt', 'verify', 'status', '1', '2', '3', '4')]
    [string]$Command,
    [string]$Recipient,
    [string]$Identity,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
if (-not $Command) {
    Write-Host '1. Encrypt and refresh the Git-safe backup'
    Write-Host '2. Decrypt and restore files to their original paths'
    Write-Host '3. Verify local files against the encrypted backup'
    Write-Host '4. Show backup status'
    $Command = Read-Host 'Choose 1, 2, 3 or 4'
}
$choices = @{ '1' = 'encrypt'; '2' = 'decrypt'; '3' = 'verify'; '4' = 'status' }
if ($choices.ContainsKey($Command)) { $Command = $choices[$Command] }
if ($Command -notin @('encrypt', 'decrypt', 'verify', 'status')) {
    throw 'Choose 1, 2, 3, 4, encrypt, decrypt, verify or status.'
}
$toolArguments = @((Join-Path $PSScriptRoot 'scripts/project_secrets.py'), $Command)
if ($Command -eq 'encrypt') {
    # Use the actual agel function from the user's PowerShell profile.
    $toolArguments += '--agel'
    if ($Recipient) { $toolArguments += @('--recipient', $Recipient) }
} elseif ($Command -in @('decrypt', 'verify')) {
    if ($Identity) { $toolArguments += @('--identity', $Identity) }
    else { $toolArguments += '--paste-key' }
    if ($Force -and $Command -eq 'decrypt') { $toolArguments += '--force' }
}
& python @toolArguments
if ($LASTEXITCODE -ne 0) { throw 'Secret operation failed; see the safe error above.' }
