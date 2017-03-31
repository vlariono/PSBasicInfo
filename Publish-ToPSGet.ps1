param(
    # APIKey
    [Parameter(Mandatory = $true, Position = 0)]
    [string]
    $ApiKey
)

try
{
    $manifestPath  = (Join-Path -Path $PSScriptRoot -ChildPath PSBasicInfo.psd1)
    $moduleManifest = Get-Content -Path $manifestPath -Raw -ErrorAction Stop|Invoke-Expression

    $moduleVersion = [System.Version]::Parse($moduleManifest.ModuleVersion)
    $moduleManifest.ModuleVersion = [version]::new($moduleVersion.Major, $moduleVersion.Minor, ($moduleVersion.Build + 1)).ToString()

    New-ModuleManifest @moduleManifest -ErrorAction Stop -Path $manifestPath
}
catch
{
    throw $_
}

#Publish-Module -Path $PSScriptRoot -NuGetApiKey ApiKey -Verbose