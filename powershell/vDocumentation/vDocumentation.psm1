#Requires -Version 7.0

# Module-level variables
$script:ModuleRoot = $PSScriptRoot

# Get public and private function definition files.
$Public = @( Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public' '*.ps1') -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private' '*.ps1') -ErrorAction SilentlyContinue )

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}
