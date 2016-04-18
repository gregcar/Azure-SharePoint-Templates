#Requires -Version 3.0

Param(
  [string] [Parameter(Mandatory=$false)] $ResourceGroupLocation = 'eastus',
  [string] [ValidateSet('SP2013-SingleServer','SP2013-SmallFarm','SP2016-SingleServer','SP2016-SmallFarm')] [Parameter(Mandatory=$false)] $ConfigName = 'SP2016-SmallFarm',
  [string] [Parameter(Mandatory=$false)] $ResourceGroupName = 'SharePoint2016-Test02',
  [switch] $SharePointOnly
)

Clear-Host
Import-Module -Name Azure -ErrorAction SilentlyContinue
Import-Module -Name AzureRM -ErrorAction SilentlyContinue
. "$PSScriptRoot\AzureSharePointDeploymentFunctions.ps1"
$ErrorActionPreference = "Stop"

Set-StrictMode -Version 3

Write-Output -InputObject "**********************************************"
Write-Output -InputObject "Begining Creation of SharePoint ARM Deployment"
Write-Output -InputObject "**********************************************"
Write-Output -InputObject "Resource Group: $ResourceGroupName"
Write-Output -InputObject "Region: $ResourceGroupLocation"
Write-Output -InputObject "Configuration: $ConfigName"
Write-Output -InputObject " "

#Login-AzureRmAccount


$storageSettings = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\Templates\$ConfigName\storage.parameters.json" -Resolve) -Raw | ConvertFrom-Json

if (-not $SharePointOnly) {
    Write-Output -InputObject "Task 1: Creating storage account"
    $ErrorActionPreference = "Stop"
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation
    New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                           -TemplateFile (Join-Path -Path $PSScriptRoot -ChildPath "..\Templates\$ConfigName\Storage.json" -Resolve) `
                           -TemplateParameterFile (Join-Path -Path $PSScriptRoot -ChildPath "..\Templates\$ConfigName\Storage.parameters.json" -Resolve) `
                           -Verbose

    Start-Sleep -Seconds 60

    Write-Output -InputObject "Task 2: Starting copy of VM image for SharePoint Servers"
    $vmimageSettings = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\Templates\$ConfigName\vmimage.json" -Resolve) -Raw | ConvertFrom-Json
    $imageCopyJob = Copy-AzureVMImageToStorageContainer -SourceStorageAccountName $vmimageSettings.AccountName -SourceStorageAccountKey $vmimageSettings.AccountKey -ImageUrl $vmimageSettings.Uri -TargetStorageAccountName $storageSettings.parameters.primaryStorageAccountName.value -ResourceGroupName $ResourceGroupName

    Write-Output -InputObject "Task 3: Publishing DSC configurations"
    $ConfigurationPath = Join-Path -Path $PSScriptRoot -ChildPath "..\Templates\$ConfigName\Configurations" -Resolve
    Get-ChildItem -Path $ConfigurationPath -File -Filter "*.ps1" | ForEach-Object {
        Publish-AzureRmVMDscConfiguration -ConfigurationPath $_.FullName -ResourceGroupName $ResourceGroupName -StorageAccountName $storageSettings.parameters.dscStorageAccountName.value -SkipDependencyDetection -Force
    }

    Write-Output -InputObject "Task 4: Launching common infrastructure VM provisioning"

    New-AzureRMResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                                     -Name "CommonInfrastructure" `
                                     -TemplateFile (Join-Path -Path $PSScriptRoot -ChildPath "..\Templates\$ConfigName\InfrastructureServers.json" -Resolve) `
                                     -TemplateParameterFile (Join-Path -Path $PSScriptRoot -ChildPath "..\Templates\$ConfigName\InfrastructureServers.parameters.json" -Resolve) `
                                     -dscSasToken (New-DscConfigurationsSasToken -ResourceGroupName $ResourceGroupName -StorageAccountName $storageSettings.parameters.dscStorageAccountName.value) `
                                     -StorageAccountName $storageSettings.parameters.primaryStorageAccountName.value `
                                     -dscStorageAccountName $storageSettings.parameters.dscStorageAccountName.value `
                                     -Verbose 

    Write-Output -InputObject "Task 5: Waiting for VM image for SharePoint servers to complete"
    $imageCopyJob | Get-AzureStorageBlobCopyState -WaitForComplete | Out-Null

    Write-Output -InputObject "Task 6: Provisioning SharePoint Servers"
} else {
    Write-Output -InputObject "Task 1: Publishing DSC configurations"
    $ConfigurationPath = Join-Path -Path $PSScriptRoot -ChildPath "..\Templates\$ConfigName\Configurations" -Resolve
    Get-ChildItem -Path $ConfigurationPath -File -Filter "*.ps1" | ForEach-Object {
        Publish-AzureVMDscConfiguration -ResourceGroupName $ResourceGroupName -ConfigurationPath $_.FullName -StorageAccountName $storageSettings.parameters.dscStorageAccountName.value -Force | Out-Null 
    }

    Write-Output -InputObject "Task 2: Provisioning SharePoint Servers"
}

New-AzureRMResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                                 -Name "SharePointServers" `
                                 -TemplateFile (Join-Path -Path $PSScriptRoot -ChildPath "..\Templates\$ConfigName\SharePointServers.json" -Resolve) `
                                 -TemplateParameterFile (Join-Path -Path $PSScriptRoot -ChildPath "..\Templates\$ConfigName\SharePointServers.parameters.json" -Resolve) `
                                 -dscSasToken (New-DscConfigurationsSasToken -ResourceGroupName $ResourceGroupName -StorageAccountName $storageSettings.parameters.dscStorageAccountName.value) `
                                 -StorageAccountName $storageSettings.parameters.primaryStorageAccountName.value `
                                 -dscStorageAccountName $storageSettings.parameters.dscStorageAccountName.value `
                                 -Verbose 

Write-Output -InputObject "Provisioning complete!"