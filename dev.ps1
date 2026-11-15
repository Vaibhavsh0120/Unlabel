[CmdletBinding()]
param([switch]$List)

$ErrorActionPreference = 'Stop'
$entries = @(
    @{ Key = '1'; Group = 'Develop'; Title = 'Set up the workspace'; Detail = 'Install locked dependencies and prepare the local catalogue.'; File = 'scripts/setup.ps1' },
    @{ Key = '2'; Group = 'Develop'; Title = 'Run Unlabel'; Detail = 'Choose local, hosted API, or LAN mode.'; File = 'scripts/run-local.ps1' },
    @{ Key = '3'; Group = 'Develop'; Title = 'Set up backend only'; Detail = 'Prepare Python and the catalogue without Flutter setup.'; File = 'scripts/setup.ps1'; Options = @{ Scope = 'backend' } },
    @{ Key = '4'; Group = 'Develop'; Title = 'Set up frontend only'; Detail = 'Prepare Flutter and restore the app dependencies.'; File = 'scripts/setup.ps1'; Options = @{ Scope = 'frontend' } },
    @{ Key = '5'; Group = 'Secrets'; Title = 'Secret backup and recovery'; Detail = 'Encrypt, restore, verify, or view the age backup inventory.'; File = 'secrets/secrets.ps1' },
    @{ Key = '6'; Group = 'Verify'; Title = 'Check repository files'; Detail = 'Check source syntax, documentation links, and version metadata.'; File = 'scripts/release/validate_workspace.py' },
    @{ Key = '7'; Group = 'Verify'; Title = 'Run backend tests'; Detail = 'Run pytest in the backend environment. Run setup first.'; File = 'backend/tests'; PythonArgs = @('-m', 'pytest', 'tests', '-q'); Backend = $true },
    @{ Key = '8'; Group = 'Verify'; Title = 'Run script tests'; Detail = 'Run the setup, release, and documentation tool tests.'; File = 'scripts/tests'; PythonArgs = @('-m', 'unittest', 'discover', '-s', 'scripts/tests', '-p', 'test_*.py') },
    @{ Key = '9'; Group = 'Verify'; Title = 'Build and verify local data'; Detail = 'Generate legacy read-only catalogue artifacts from committed sources. Run setup first.'; File = 'backend/build_catalogue.py'; Backend = $true }
)

function Show-Menu {
    Write-Host ''
    Write-Host 'Unlabel developer tools' -ForegroundColor Green
    $group = ''
    foreach ($entry in $entries) {
        if ($group -ne $entry.Group) {
            $group = $entry.Group
            Write-Host "`n$group" -ForegroundColor Cyan
        }
        Write-Host ('  [{0}] {1}' -f $entry.Key, $entry.Title)
        Write-Host ('      ' + $entry.Detail)
    }
    Write-Host "`n  [0] Exit"
}

function Invoke-Entry($entry) {
    $scriptPath = Join-Path $PSScriptRoot $entry.File
    if ($scriptPath.EndsWith('.ps1')) {
        $options = @{}
        if ($entry.Options) { $options = $entry.Options }
        & $scriptPath @options
        return
    }

    if ($entry.PythonArgs) { $arguments = $entry.PythonArgs }
    else { $arguments = @($scriptPath) }
    $venv = Join-Path $PSScriptRoot 'backend/.venv/Scripts/python.exe'
    if (!(Test-Path -LiteralPath $venv -PathType Leaf)) {
        $venv = Join-Path $PSScriptRoot 'backend/.venv/bin/python'
    }
    if ($entry.Backend) {
        if (!(Test-Path -LiteralPath $venv -PathType Leaf)) { throw 'Run backend setup first.' }
        Push-Location (Join-Path $PSScriptRoot 'backend')
        try { & $venv @arguments }
        finally { Pop-Location }
    } elseif (Test-Path -LiteralPath $venv -PathType Leaf) {
        & $venv @arguments
    } elseif (Get-Command py -CommandType Application -ErrorAction SilentlyContinue) {
        & py -3 @arguments
    } elseif (Get-Command python3 -CommandType Application -ErrorAction SilentlyContinue) {
        & python3 @arguments
    } else {
        & python @arguments
    }
}

if ($List) { Show-Menu; return }

Push-Location $PSScriptRoot
try {
    while ($true) {
        Show-Menu
        $choice = Read-Host 'Choose a tool'
        if ($null -eq $choice -or $choice.Trim() -eq '0') { break }
        $entry = $entries | Where-Object { $_.Key -eq $choice.Trim() }
        if (!$entry) {
            Write-Host 'Enter one of the numbers shown above.' -ForegroundColor Yellow
            continue
        }
        Write-Host ("`n" + $entry.Title) -ForegroundColor Cyan
        try {
            Invoke-Entry $entry
            if ($LASTEXITCODE -eq 0) { Write-Host 'Tool finished.' -ForegroundColor Green }
            else { Write-Host "Tool exited with code $LASTEXITCODE." -ForegroundColor Yellow }
        } catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
} finally {
    Pop-Location
}
