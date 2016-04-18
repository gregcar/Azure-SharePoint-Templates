function Format-DscScriptBlock()
{
    param(
        [parameter(Mandatory=$true)]
        [System.Collections.Hashtable] $replaceValues,
        [parameter(Mandatory=$true)]
        [System.Management.Automation.ScriptBlock] $scriptBlock
    )
    $result = $scriptBlock.ToString();
    foreach($key in $replaceValues.Keys )
    {
        $result = $result.Replace($key, $replaceValues[$key]);
    }
    return $result;
}

Configuration SharePointWFEServer
{
    param (
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $CredSSPDelegates,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $FarmAccount,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SPSetupAccount,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $DatabaseServer,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $FarmPassPhrase,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $WebPoolManagedAccount,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $ServicePoolManagedAccount,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $WebAppUrl,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $MySiteHostUrl,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [int]          $CacheSizeInMB,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $DomainName,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $domainAdminCredential,
		[Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]       $ServerNamePrefix
    )

	Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xSharePoint
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName xCredSSP
    Import-DscResource -ModuleName xDisk
    Import-DscResource -ModuleName xComputerManagement

    node "localhost"
    {
        #**********************************************************
        # Server configuration
        #
        # This section of the configuration includes details of the
        # server level configuration, such as disks, registry
        # settings etc.
        #********************************************************** 

        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $domainAdminCredential
        }
        xDisk LogsDisk { DiskNumber = 2; DriveLetter = "l"; DependsOn = "[xComputer]DomainJoin" }
        xDisk IndexDisk { DiskNumber = 3; DriveLetter = "i"; DependsOn = "[xComputer]DomainJoin" }
        xCredSSP CredSSPServer { Ensure = "Present"; Role = "Server"; DependsOn = "[xComputer]DomainJoin" } 
        xCredSSP CredSSPClient { Ensure = "Present"; Role = "Client"; DelegateComputers = $CredSSPDelegates; DependsOn = "[xComputer]DomainJoin" }
		Script AddSPSetupLocalAdmin
        {
            GetScript = "return @{}"
            TestScript = Format-DscScriptBlock -replaceValues @{
                "`$USERNAME" = $SPSetupAccount.UserName.Split('\')[1]
				"`$USERDOMAIN" = $SPSetupAccount.UserName.Split('\')[0]
            } -scriptBlock {
				return ((([ADSI]"WinNT://$($env:computername)/Administrators,group").PSBase.Invoke("Members") | 
					ForEach-Object {$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)} | 
					Where-Object { $_ -eq "$USERNAME" }) -ne $null)
            }
            SetScript = Format-DscScriptBlock -replaceValues @{
                "`$USERNAME" = $SPSetupAccount.UserName.Split('\')[1]
				"`$USERDOMAIN" = $SPSetupAccount.UserName.Split('\')[0]
            } -scriptBlock {
				([ADSI]"WinNT://$($env:computername)/Administrators,group").Add("WinNT://$USERDOMAIN/$USERNAME") | Out-Null
				$global:DSCMachineStatus = 1
            }
			DependsOn = "[xComputer]DomainJoin"
        }


        #**********************************************************
        # IIS clean up
        #
        # This section removes all default sites and application
        # pools from IIS as they are not required
        #**********************************************************

        xWebAppPool RemoveDotNet2Pool         { Name = ".NET v2.0";            Ensure = "Absent"; }
        xWebAppPool RemoveDotNet2ClassicPool  { Name = ".NET v2.0 Classic";    Ensure = "Absent"; }
        xWebAppPool RemoveDotNet45Pool        { Name = ".NET v4.5";            Ensure = "Absent"; }
        xWebAppPool RemoveDotNet45ClassicPool { Name = ".NET v4.5 Classic";    Ensure = "Absent"; }
        xWebAppPool RemoveClassicDotNetPool   { Name = "Classic .NET AppPool"; Ensure = "Absent"; }
        xWebAppPool RemoveDefaultAppPool      { Name = "DefaultAppPool";       Ensure = "Absent"; }
        xWebSite    RemoveDefaultWebSite      { Name = "Default Web Site";     Ensure = "Absent"; PhysicalPath = "C:\inetpub\wwwroot"; }
        

        #**********************************************************
        # Basic farm configuration
        #
        # This section creates the new SharePoint farm object, and
        # provisions generic services and components used by the
        # whole farm
        #**********************************************************

        WaitForAll WaitForFarmToExist
        {
            ResourceName         = "[xSPCreateFarm]CreateSPFarm"
            NodeName             = "$ServerNamePrefix-sp1"
            RetryIntervalSec     = 60
            RetryCount           = 60
            PsDscRunAsCredential = $SPSetupAccount
        }
        xSPJoinFarm JoinSPFarm
        {
            DatabaseServer           = $DatabaseServer
            FarmConfigDatabaseName   = "SP_Config"
            Passphrase               = $FarmPassPhrase
            PsDscRunAsCredential     = $SPSetupAccount
            DependsOn                = "[WaitForAll]WaitForFarmToExist"
        }
        WaitForAll WaitForDCache
        {
            ResourceName         = "[xSPDistributedCacheService]EnableDistributedCache"
            NodeName             = "gcsmlsp16-sp3"
            RetryIntervalSec     = 60
            RetryCount           = 60
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPJoinFarm]JoinSPFarm"
        }
        xSPDistributedCacheService EnableDistributedCache
        {
            Name                 = "AppFabricCachingService"
            Ensure               = "Present"
            CacheSizeInMB        = $CacheSizeInMB
            ServiceAccount       = $ServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccount
            CreateFirewallRules  = $true
            DependsOn            = "[WaitForAll]WaitForDCache"
        }

        #**********************************************************
        # Service instances
        #
        # This section describes which services should be running
        # and not running on the server
        #**********************************************************

        xSPServiceInstance ClaimsToWindowsTokenServiceInstance
        {  
            Name                 = "Claims to Windows Token Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPJoinFarm]JoinSPFarm"
        }        
        xSPServiceInstance SecureStoreServiceInstance
        {  
            Name                 = "Secure Store Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPJoinFarm]JoinSPFarm"
        }
        xSPServiceInstance ManagedMetadataServiceInstance
        {  
            Name                 = "Managed Metadata Web Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPJoinFarm]JoinSPFarm"
        }
        xSPServiceInstance BCSServiceInstance
        {  
            Name                 = "Business Data Connectivity Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPJoinFarm]JoinSPFarm"
        }

        #**********************************************************
        # Local configuration manager settings
        #
        # This section contains settings for the LCM of the host
        # that this configuraiton is applied to
        #**********************************************************
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }
    }
}