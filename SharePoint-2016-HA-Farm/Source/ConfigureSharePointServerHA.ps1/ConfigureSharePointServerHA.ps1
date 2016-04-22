#
# Copyright="� Microsoft Corporation. All rights reserved."
#

configuration ConfigureSharePointServerHA
{

    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SharePointSetupUserAccountcreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SharePointFarmAccountcreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SharePointFarmPassphrasecreds,

        [parameter(Mandatory)]
        [String]$DatabaseName,

        [parameter(Mandatory)]
        [String]$AdministrationContentDatabaseName,

        [parameter(Mandatory)]
        [String]$DatabaseServer,

        [parameter(Mandatory)]
        [String]$Configuration,

        [String]$SqlAlwaysOnAvailabilityGroupName,

        [String[]]$DatabaseNames,

        [String]$PrimaryReplica,

        [String]$SecondaryReplica,

        [System.Management.Automation.PSCredential]$SQLServiceCreds,

        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),

        [Int]$RetryCount=30,
        [Int]$RetryIntervalSec=60
    )

        Write-Verbose "AzureExtensionHandler loaded continuing with configuration"

        [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
        [System.Management.Automation.PSCredential ]$FarmCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SharePointFarmAccountcreds.UserName)", $SharePointFarmAccountcreds.Password)
        [System.Management.Automation.PSCredential ]$SPsetupCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SharePointSetupUserAccountcreds.UserName)", $SharePointSetupUserAccountcreds.Password)
        [System.Management.Automation.PSCredential]$SQLCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SQLServiceCreds.UserName)", $SQLServiceCreds.Password)

        # Install Sharepoint Module
        $ModuleFilePath="$PSScriptRoot\SharePointServer.psm1"
        $ModuleName = "SharepointServer"
        $PSModulePath = $Env:PSModulePath -split ";" | Select -Index 1
        $ModuleFolder = "$PSModulePath\$ModuleName"
        if (-not (Test-Path  $ModuleFolder -PathType Container)) {
            mkdir $ModuleFolder
        }
        Copy-Item $ModuleFilePath $ModuleFolder -Force


        $SQLCLRPath="${PSScriptRoot}\SQLSysClrTypes.msi"
        $SMOPath="${PSScriptRoot}\SharedManagementObjects.msi"
        $SQLPSPath="${PSScriptRoot}\PowerShellTools.msi"

        Import-DscResource -ModuleName xComputerManagement, xActiveDirectory, cConfigureSharepoint,xSQL

        Node localhost
        {

            LocalConfigurationManager
            {
                RebootNodeIfNeeded = $true
            }

            xWaitForADDomain DscForestWait
            {
                DomainName = $DomainName
                DomainUserCredential= $DomainCreds
                RetryCount = $RetryCount
                RetryIntervalSec = $RetryIntervalSec
            }

            xComputer DomainJoin
            {
                Name = $env:COMPUTERNAME
                DomainName = $DomainName
                Credential = $DomainCreds
                DependsOn = "[xWaitForADDomain]DscForestWait"
            }

            Group AddSetupUserAccountToLocalAdminsGroup
            {
                GroupName = "Administrators"
                Credential = $DomainCreds
                MembersToInclude = "${DomainName}\$($SharePointSetupUserAccountcreds.UserName)"
                Ensure="Present"
                DependsOn = "[xComputer]DomainJoin"
            }

            xADUser CreateFarmAccount
            {
                DomainAdministratorCredential = $DomainCreds
                DomainName = $DomainName
                UserName = $SharePointFarmAccountcreds.UserName
                Password =$FarmCreds
                Ensure = "Present"
                DependsOn = "[xComputer]DomainJoin"
            }

            cConfigureSharepoint ConfigureSharepointServer
            {
                DomainName=$DomainName
                DomainAdministratorCredential=$DomainCreds
                DatabaseName=$DatabaseName
                AdministrationContentDatabaseName=$AdministrationContentDatabaseName
                DatabaseServer=$DatabaseServer
                SetupUserAccountCredential=$SPsetupCreds
                FarmAccountCredential=$SharePointFarmAccountcreds
                FarmPassphrase=$SharePointFarmPassphrasecreds
                Configuration=$Configuration
                DependsOn = "[xADUser]CreateFarmAccount", "[Group]AddSetupUserAccountToLocalAdminsGroup"
            }

            # These packages should really only be installed on one server but they only take seconds to install and dont require a reboot

            Package SQLCLRTypes
            {
                Ensure = 'Present'
                Path  =  $SQLCLRPath
                Name = 'Microsoft System CLR Types for SQL Server 2012 (x64)'
                ProductId = 'F1949145-EB64-4DE7-9D81-E6D27937146C'
                Credential= $Admincreds
            }
            Package SharedManagementObjects
            {
                Ensure = 'Present'
                Path  = $SMOPath
                Name = 'Microsoft SQL Server 2012 Management Objects  (x64)'
                ProductId = 'FA0A244E-F3C2-4589-B42A-3D522DE79A42'
                Credential = $Admincreds
            }

            # This does nothing if Databasenames is null

            xSqlNewAGDatabase SQLAGDatabases
            {
                SqlAlwaysOnAvailabilityGroupName = $SqlAlwaysOnAvailabilityGroupName
                DatabaseNames = $DatabaseNames
                PrimaryReplica = $PrimaryReplica
                SecondaryReplica = $SecondaryReplica
                SqlAdministratorCredential = $SQLCreds
            }
            cConfigureSPSDBDFailover UpdateSPFailover
            {
                DatabaseNames = $DatabaseNames
                FailoverServerInstance = $SecondaryReplica
                SharePointSetupUserAccountcreds=  $SPsetupCreds
            }
        }

}
function Get-NetBIOSName
{
    [OutputType([string])]
    param(
        [string]$DomainName
    )

    if ($DomainName.Contains('.')) {
        $length=$DomainName.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainName.Substring(0,$length)
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0,15)
        }
        else {
            return $DomainName
        }
    }
}
function Update-SPFailOverInstance
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$DatabaseName
    )

    try
    {
        Get-SPDatabase | ForEach-Object
        {
            If ($_.Name -eq $DatabaseName)
            {
                $_.AddFailoverServiceInstance($FailoverServerInstance)
                $_.Update()
                Write-Verbose -Message "Updated database failover instance for '$($_.Name)'."
            }
        }
    }
    catch
    {
            Write-Verbose -Message "FAILED: Updating database failover instance for '$($_.Name)'."
    }
}
