$resourceGroup = "SharePoint2016-Test06"
$spStorageAccount = "gcsp01str3"
$adStorageAccount = "gcsp01str1"
$ErrorActionPreference = "Stop"

Select-AzureRmSubscription -SubscriptionId "1c543ebe-dd69-4702-a884-3a19bdc35328"

$spStorageContext = New-AzureStorageContext -StorageAccountName $spStorageAccount -StorageAccountKey (Get-AzureRmStorageAccountKey -StorageAccountName $spStorageAccount -ResourceGroupName $resourceGroup).Key1
$adStorageContext = New-AzureStorageContext -StorageAccountName $adStorageAccount -StorageAccountKey (Get-AzureRmStorageAccountKey -StorageAccountName $adStorageAccount -ResourceGroupName $resourceGroup).Key1

#Clean up SharePoint
Write-Host "Cleaning up SharePoint VM"
Remove-AzureRmVM -Name "sps-app-0" -ResourceGroupName $resourceGroup -Force
Get-AzureStorageBlob -Context $spStorageContext -Container "vhds" | Where-Object { $_.BlobType -eq "PageBlob" -and $_.Name -like "sps-app-0-*.vhd"} | Remove-AzureStorageBlob


#Clean up BDC
Write-Host "Cleaning up BDC VM"
Remove-AzureRmVM -Name "ad-bdc" -ResourceGroupName $resourceGroup -Force
Get-AzureStorageBlob -Context $adStorageContext -Container "vhds" | Where-Object { $_.BlobType -eq "PageBlob" -and $_.Name -like "ad-bdc*.vhd"} | Remove-AzureStorageBlob

Write-Host "Cleanup Complete!"