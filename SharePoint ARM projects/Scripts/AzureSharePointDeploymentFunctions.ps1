#*************************************************************
#
#    Azure SharePoint Deployment Helper Functions
#
#    This file contains a number of common functions designed
#    to assist in the deployment of SharePoint environments
#    in Azure
#
#*************************************************************


# This function simplifies the process of getting an ad hoc SAS token against a storage 
# container, defaulting to the DSC configuration container we create to publish the ZIP
# packages. This function will only work against v2 storage in Azure.
function New-DscConfigurationsSasToken() {
    [CmdletBinding()]
    param
    (
        [string] [parameter(Mandatory = $true)] $StorageAccountName,
        [string] [parameter(Mandatory = $true)] $ResourceGroupName,
        [string] [parameter(Mandatory = $false)] $ContainerName = 'windows-powershell-dsc',
        [int] [parameter(Mandatory = $false)] $Hours = 12
    )
    $key = (Get-AzureRMStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName).Key1
    $context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $key
    $sasToken = New-AzureStorageContainerSASToken -Name $ContainerName -Permission r -ExpiryTime ([System.DateTime]::Now.AddHours($Hours)) -Context $context

    return $sasToken
}

# This function takes details of where a VM image is located and copies it to a new storage
# account. It works for v2 storage accounts as the target, but the source should be able to 
# be either v1 or v2, although only v2 has been tested here. 
function Copy-AzureVMImageToStorageContainer() {
    [CmdletBinding()]
    param
    (
        [string] [parameter(Mandatory = $true)] $SourceStorageAccountName,
        [string] [parameter(Mandatory = $true)] $SourceStorageAccountKey,
        [string] [parameter(Mandatory = $true)] $ImageUrl,
        [string] [parameter(Mandatory = $true)] $TargetStorageAccountName,
        [string] [parameter(Mandatory = $false)] $TargetStorageAccountContainer = 'vhds',
        [string] [parameter(Mandatory = $true)] $ResourceGroupName
    )

    $srcContext = New-AzureStorageContext -StorageAccountName $SourceStorageAccountName -StorageAccountKey $SourceStorageAccountKey
    $key = (Get-AzureRMStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $TargetStorageAccountName).Key1
    $destContext = New-AzureStorageContext -StorageAccountName $TargetStorageAccountName -StorageAccountKey $key

    $container = Get-AzureStorageContainer -Name $TargetStorageAccountContainer -Context $destContext -ErrorAction SilentlyContinue
    if ($container -eq $null) {
        New-AzureStorageContainer -Name $TargetStorageAccountContainer -Context $destContext | Out-Null
    }

    $ImageCopy = Start-AzureStorageBlobCopy -SrcUri $ImageUrl -DestContainer $TargetStorageAccountContainer -DestBlob (Split-Path -Path $ImageUrl -Leaf) -Context $srcContext -DestContext $destContext
    return $ImageCopy
}

