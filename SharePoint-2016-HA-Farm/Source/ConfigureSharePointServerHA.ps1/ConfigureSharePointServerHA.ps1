#
# Copyright="Microsoft Corporation. All rights reserved."
#

configuration ConfigureSharePointServerFarm
{

    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

		[Parameter(Mandatory)]
        [String]$FirstFarmMember,

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
        # $ModuleFilePath="$PSScriptRoot\SharePointServer.psm1"
        # $ModuleName = "SharepointServer"
        # $PSModulePath = $Env:PSModulePath -split ";" | Select -Index 1
        # $ModuleFolder = "$PSModulePath\$ModuleName"
        #if (-not (Test-Path  $ModuleFolder -PathType Container)) {
        #    mkdir $ModuleFolder
        #}
        #Copy-Item $ModuleFilePath $ModuleFolder -Force


        $SQLCLRPath="${PSScriptRoot}\SQLSysClrTypes.msi"
        $SMOPath="${PSScriptRoot}\SharedManagementObjects.msi"
        $SQLPSPath="${PSScriptRoot}\PowerShellTools.msi"

        Import-DscResource -ModuleName xComputerManagement
		Import-DscResource -ModuleName xActiveDirectory
		Import-DscResource -ModuleName xSharepoint
		Import-DscResource -ModuleName xSQL

        Node localhost
        {

            LocalConfigurationManager
            {
                RebootNodeIfNeeded = $true
				DebugMode = $true
				AllowModuleOverwrite = $true
				ConfigurationModeFrequencyMins = 1
				RefreshFrequencyMins = 1
				RefreshMode = "Pull"
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

			if ($FirstFarmMember = "true") {
				xSPCreateFarm CreateSPFarm
				{
					DatabaseServer           = $DatabaseServer
					FarmConfigDatabaseName   = $DatabaseNames[1]
					Passphrase               = $SharePointFarmPassphrasecreds
					FarmAccount              = $FarmCreds
					InstallAccount           = $SPsetupCreds
					AdminContentDatabaseName = $AdministrationContentDatabaseName
					DependsOn                = "[xSPInstall]InstallSharePoint"
				}

				$FarmWaitTask = "[xSPCreateFarm]CreateSPFarm"

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
			} else {
				WaitForAll WaitForFarmToExist
				{
					ResourceName         = "[xSPCreateFarm]CreateSPFarm"
					NodeName             = "sps-app-0"
					RetryIntervalSec     = 60
					RetryCount           = 60
					PsDscRunAsCredential = $SPsetupCreds
				}
				xSPJoinFarm JoinSPFarm
				{
					DatabaseServer           = $DatabaseServer
					FarmConfigDatabaseName   = $DatabaseNames[1]
					Passphrase               = $SharePointFarmPassphrasecreds
					InstallAccount           = $SPsetupCreds
					DependsOn                = "[WaitForAll]WaitForFarmToExist"
				}

				$FarmWaitTask = "[xSPJoinFarm]JoinSPFarm"
			}

            #cConfigureSharepoint ConfigureSharepointServer
            #{
            #    DomainName=$DomainName
            #    DomainAdministratorCredential=$DomainCreds
            #    DatabaseName=$DatabaseName
            #    AdministrationContentDatabaseName=$AdministrationContentDatabaseName
            #    DatabaseServer=$DatabaseServer
            #    SetupUserAccountCredential=$SPsetupCreds
            #    FarmAccountCredential=$SharePointFarmAccountcreds
            #    FarmPassphrase=$SharePointFarmPassphrasecreds
            #    Configuration=$Configuration
            #    DependsOn = "[xADUser]CreateFarmAccount", "[Group]AddSetupUserAccountToLocalAdminsGroup"
            #}

            # This does nothing if Databasenames is null

            #xSqlNewAGDatabase SQLAGDatabases
            #{
            #    SqlAlwaysOnAvailabilityGroupName = $SqlAlwaysOnAvailabilityGroupName
            #    DatabaseNames = $DatabaseNames
            #    PrimaryReplica = $PrimaryReplica
            #    SecondaryReplica = $SecondaryReplica
            #    SqlAdministratorCredential = $SQLCreds
            #}
            #cConfigureSPSDBDFailover UpdateSPFailover
            #{
            #    DatabaseNames = $DatabaseNames
            #    FailoverServerInstance = $SecondaryReplica
            #    SharePointSetupUserAccountcreds=  $SPsetupCreds
            #}
        }
}
ConfigureSharePointServerFarm

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
