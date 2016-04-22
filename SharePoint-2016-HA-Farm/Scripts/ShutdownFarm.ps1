Param(
    [bool] $ShutdownFarm = $false,

    [string] $ResourceGroupName = 'SharePoint2016-Test06'
    )

Write-Host "The value is: " $ShutdownFarm

if ($ShutdownFarm) {
    Write-Host "The farm will be shutdown momentarily..."
    #SharePoint VMs
    Stop-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sps-web-0"
    Stop-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sps-web-1"
    Stop-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sps-app-1"
    Stop-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sps-app-0"

    #SQL VMs
    Stop-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sql-1"
    Stop-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sql-w"
    Stop-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sql-0"

    #AD VMs
    Stop-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "ad-bdc"
    Stop-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "ad-pdc"

} else {
    Write-Host "The farm will be started momentarily..."
    #AD VMs
    Start-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "ad-pdc"
    Start-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "ad-bdc"

    #SQL VMs
    Start-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sql-0"
    Start-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sql-w"
    Start-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sql-1"

    #SharePoint VMs
    Start-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sps-app-0"
    Start-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sps-web-0"
    Start-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sps-web-1"
    Start-AzureRmVM -ResourceGroup $ResourceGRoupName -Force -Name "sps-app-1"
}
