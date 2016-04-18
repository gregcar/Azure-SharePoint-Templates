#Requires -Version 3.0

Param(
  [string] [ValidateSet('SP2013-SingleServer','SP2013-SmallFarm','SP2016-SingleServer','SP2016-SmallFarm')] [Parameter(Mandatory=$true)] $ResourceGroupName,
  [switch] $SharePointOnly
)

Switch-AzureMode -Name AzureResourceManager
Clear-Host
Import-Module -Name Azure -ErrorAction SilentlyContinue
. "$PSScriptRoot\AzureSharePointDeploymentFunctions.ps1"
$ErrorActionPreference = "Stop"

Set-StrictMode -Version 3

Write-Output -InputObject "**********************************************"
Write-Output -InputObject "Begining Deletion of SharePoint ARM Deployment"
Write-Output -InputObject "**********************************************"
Write-Output -InputObject "Resource Group: $ResourceGroupName"
Write-Output -InputObject " "

$ErrorActionPreference = "Stop"

if (-not $SharePointOnly) {
    Write-Output -InputObject "Task 1: Removing resource group"    
    Remove-AzureResourceGroup -Name $ResourceGroupName -Force -Confirm:$false
} else {
    $CleanUpDetails = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\Templates\$ResourceGroupName\SharePointCleanup.json" -Resolve) -Raw | ConvertFrom-Json

    Write-Output -InputObject "Task 1: Removing SharePoint VMs"    
    $CleanUpDetails.SharePointServers | ForEach-Object {
        Remove-AzureVM -ResourceGroupName $ResourceGroupName -Name $_ -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Output -InputObject "Task 2: Removing SharePoint Network Interfaces"
    $CleanUpDetails.NetworkInterfaces  | ForEach-Object {
        Remove-AzureNetworkInterface -ResourceGroupName $ResourceGroupName -Name $_ -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Output -InputObject "Task 3: Removing SharePoint Public IPs"
    $CleanUpDetails.PublicIPs  | ForEach-Object {
        Remove-AzurePublicIpAddress -ResourceGroupName $ResourceGroupName -Name $_ -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Write-Output -InputObject "Task 4: Removing Disks"
    $CleanUpDetails.Blobs | ForEach-Object {
        try
        {
            $key = (Get-AzureStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $_.Account).Key1
            $context = New-AzureStorageContext -StorageAccountName $_.Account -StorageAccountKey $key
            Remove-AzureStorageBlob -Blob $_.Blob -Container $_.Container -Context $context
        } catch {}
    }
}

Write-Output -InputObject "Retraction complete!"