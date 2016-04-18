#Requires -Version 3.0

Param(
  [string] [ValidateSet('SP2013-SingleServer','SP2013-SmallFarm','SP2016-SingleServer','SP2016-SmallFarm')] [Parameter(Mandatory=$true)] $ResourceGroupName
)

Clear-Host
Import-Module -Name Azure -ErrorAction SilentlyContinue
. "$PSScriptRoot\AzureSharePointDeploymentFunctions.ps1"
$ErrorActionPreference = "Stop"

Set-StrictMode -Version 3

Write-Output -InputObject "**********************************************"
Write-Output -InputObject " Shutting down SharePoint Resource Group VMs"
Write-Output -InputObject "**********************************************"
Write-Output -InputObject "Resource Group: $ResourceGroupName"


Switch-AzureMode -Name AzureResourceManager
$ErrorActionPreference = "Stop"

Write-Output -InputObject "Task 1: Shutting down VMs"    
Get-AzureVM -ResourceGroupName $ResourceGroupName | Stop-AzureVM -Force | Out-Null

Write-Output -InputObject "All VMs are now shutting down"    
