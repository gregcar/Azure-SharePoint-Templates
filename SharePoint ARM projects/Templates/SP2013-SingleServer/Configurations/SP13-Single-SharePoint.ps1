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

Configuration SharePointServer
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
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $domainAdminCredential
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
        xDisk LogsDisk { DiskNumber = 2; DriveLetter = "l" }
        xDisk IndexDisk { DiskNumber = 3; DriveLetter = "i" }
        xCredSSP CredSSPServer { Ensure = "Present"; Role = "Server" } 
        xCredSSP CredSSPClient { Ensure = "Present"; Role = "Client"; DelegateComputers = $CredSSPDelegates }
        Registry DisableLoopBackCheck {
            Ensure = "Present"
            Key = "HKLM:\System\CurrentControlSet\Control\Lsa"
            ValueName = "DisableLoopbackCheck"
            ValueData = "1"
            ValueType = "Dword"
        }
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

        xWebAppPool RemoveDotNet2Pool         { Name = ".NET v2.0";            Ensure = "Absent" }
        xWebAppPool RemoveDotNet2ClassicPool  { Name = ".NET v2.0 Classic";    Ensure = "Absent" }
        xWebAppPool RemoveDotNet45Pool        { Name = ".NET v4.5";            Ensure = "Absent"; }
        xWebAppPool RemoveDotNet45ClassicPool { Name = ".NET v4.5 Classic";    Ensure = "Absent"; }
        xWebAppPool RemoveClassicDotNetPool   { Name = "Classic .NET AppPool"; Ensure = "Absent" }
        xWebAppPool RemoveDefaultAppPool      { Name = "DefaultAppPool";       Ensure = "Absent" }
        xWebSite    RemoveDefaultWebSite      { Name = "Default Web Site";     Ensure = "Absent"; PhysicalPath = "C:\inetpub\wwwroot" }
        

        #**********************************************************
        # Basic farm configuration
        #
        # This section creates the new SharePoint farm object, and
        # provisions generic services and components used by the
        # whole farm
        #**********************************************************
        xSPCreateFarm CreateSPFarm
        {
            DatabaseServer           = $DatabaseServer
            FarmConfigDatabaseName   = "SP_Config"
            Passphrase               = $FarmPassPhrase
            FarmAccount              = $FarmAccount
            PsDscRunAsCredential     = $SPSetupAccount
            AdminContentDatabaseName = "SP_AdminContent"
            DependsOn                = "[xComputer]DomainJoin"
        }
        xSPManagedAccount ServicePoolManagedAccount
        {
            AccountName          = $ServicePoolManagedAccount.UserName
            Account              = $ServicePoolManagedAccount
            Schedule             = ""
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPCreateFarm]CreateSPFarm"
        }
        xSPManagedAccount WebPoolManagedAccount
        {
            AccountName          = $WebPoolManagedAccount.UserName
            Account              = $WebPoolManagedAccount
            Schedule             = ""
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPCreateFarm]CreateSPFarm"
        }
        xSPDiagnosticLoggingSettings ApplyDiagnosticLogSettings
        {
            PsDscRunAsCredential                        = $SPSetupAccount
            LogPath                                     = "L:\ULSLogs"
            LogSpaceInGB                                = 10
            AppAnalyticsAutomaticUploadEnabled          = $false
            CustomerExperienceImprovementProgramEnabled = $true
            DaysToKeepLogs                              = 7
            DownloadErrorReportingUpdatesEnabled        = $false
            ErrorReportingAutomaticUploadEnabled        = $false
            ErrorReportingEnabled                       = $false
            EventLogFloodProtectionEnabled              = $true
            EventLogFloodProtectionNotifyInterval       = 5
            EventLogFloodProtectionQuietPeriod          = 2
            EventLogFloodProtectionThreshold            = 5
            EventLogFloodProtectionTriggerPeriod        = 2
            LogCutInterval                              = 15
            LogMaxDiskSpaceUsageEnabled                 = $true
            ScriptErrorReportingDelay                   = 30
            ScriptErrorReportingEnabled                 = $true
            ScriptErrorReportingRequireAuth             = $true
            DependsOn                                   = @("[xSPCreateFarm]CreateSPFarm", "[xDisk]LogsDisk")
        }
        xSPUsageApplication UsageApplication 
        {
            Name                  = "Usage Service Application"
            DatabaseName          = "SP_Usage"
            UsageLogCutTime       = 5
            UsageLogLocation      = "L:\UsageLogs"
            UsageLogMaxFileSizeKB = 1024
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = "[xSPCreateFarm]CreateSPFarm"
        }
        xSPStateServiceApp StateServiceApp
        {
            Name                 = "State Service Application"
            DatabaseName         = "SP_State"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPCreateFarm]CreateSPFarm"
        }
        xSPDistributedCacheService EnableDistributedCache
        {
            Name                 = "AppFabricCachingService"
            Ensure               = "Present"
            CacheSizeInMB        = $CacheSizeInMB
            ServiceAccount       = $ServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccount
            CreateFirewallRules  = $true
            DependsOn            = @('[xSPCreateFarm]CreateSPFarm','[xSPManagedAccount]ServicePoolManagedAccount')
        }

        #**********************************************************
        # Web applications
        #
        # This section creates the web applications in the 
        # SharePoint farm, as well as managed paths and other web
        # application settings
        #**********************************************************

        xSPWebApplication HostNameSiteCollectionWebApp
        {
            Name                   = "SharePoint Sites"
            ApplicationPool        = "SharePoint Sites"
            ApplicationPoolAccount = $WebPoolManagedAccount.UserName
            AllowAnonymous         = $false
            AuthenticationMethod   = "NTLM"
            DatabaseName           = "SP_Content_01"
            DatabaseServer         = $DatabaseServer
            Url                    = $WebAppUrl
            Port                   = 80
            PsDscRunAsCredential   = $SPSetupAccount
            DependsOn              = "[xSPManagedAccount]WebPoolManagedAccount"
        }
        xSPManagedPath TeamsManagedPath 
        {
            WebAppUrl            = "http://$WebAppUrl"
            PsDscRunAsCredential = $SPSetupAccount
            RelativeUrl          = "teams"
            Explicit             = $false
            HostHeader           = $true
            DependsOn            = "[xSPWebApplication]HostNameSiteCollectionWebApp"
        }
        xSPManagedPath PersonalManagedPath 
        {
            WebAppUrl            = "http://$WebAppUrl"
            PsDscRunAsCredential = $SPSetupAccount
            RelativeUrl          = "personal"
            Explicit             = $false
            HostHeader           = $true
            DependsOn            = "[xSPWebApplication]HostNameSiteCollectionWebApp"
        }
        xSPCacheAccounts SetCacheAccounts
        {
            WebAppUrl              = "http://$WebAppUrl"
            SuperUserAlias         = "AZUREDEMO\svcSPSuperUser"
            SuperReaderAlias       = "AZUREDEMO\svcSPReader"
            PsDscRunAsCredential   = $SPSetupAccount
            DependsOn              = "[xSPWebApplication]HostNameSiteCollectionWebApp"
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
            DependsOn            = "[xSPCreateFarm]CreateSPFarm"
        } 
        xSPServiceInstance UserProfileServiceInstance
        {  
            Name                 = "User Profile Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPCreateFarm]CreateSPFarm"
        }        
        xSPServiceInstance SecureStoreServiceInstance
        {  
            Name                 = "Secure Store Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPCreateFarm]CreateSPFarm"
        }
        xSPServiceInstance ManagedMetadataServiceInstance
        {  
            Name                 = "Managed Metadata Web Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPCreateFarm]CreateSPFarm"
        }
        xSPServiceInstance BCSServiceInstance
        {  
            Name                 = "Business Data Connectivity Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPCreateFarm]CreateSPFarm"
        }
        xSPUserProfileSyncService UserProfileSyncService
        {  
            UserProfileServiceAppName = "User Profile Service Application"
            Ensure                    = "Present"
            FarmAccount               = $FarmAccount
            PsDscRunAsCredential      = $SPSetupAccount
            DependsOn                 = "[xSPUserProfileServiceApp]UserProfileServiceApp"
        }

        #**********************************************************
        # Service applications
        #
        # This section creates service applications and required
        # dependencies
        #**********************************************************

        xSPServiceAppPool MainServiceAppPool
        {
            Name                 = "SharePoint Service Applications"
            ServiceAccount       = $ServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[xSPCreateFarm]CreateSPFarm"
        }
        xSPUserProfileServiceApp UserProfileServiceApp
        {
            Name                 = "User Profile Service Application"
            ApplicationPool      = "SharePoint Service Applications"
            MySiteHostLocation   = "http://$MySiteHostUrl"
            ProfileDBName        = "SP_UserProfiles"
            ProfileDBServer      = $DatabaseServer
            SocialDBName         = "SP_Social"
            SocialDBServer       = $DatabaseServer
            SyncDBName           = "SP_ProfileSync"
            SyncDBServer         = $DatabaseServer
            FarmAccount          = $FarmAccount
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = @('[xSPServiceAppPool]MainServiceAppPool', '[xSPManagedPath]PersonalManagedPath', '[xSPSite]MySiteHost', '[xSPManagedMetaDataServiceApp]ManagedMetadataServiceApp', '[xSPSearchServiceApp]SearchServiceApp')
        }
        xSPSecureStoreServiceApp SecureStoreServiceApp
        {
            Name                  = "Secure Store Service Application"
            ApplicationPool       = "SharePoint Service Applications"
            AuditingEnabled       = $true
            AuditlogMaxSize       = 30
            DatabaseName          = "SP_SecureStore"
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = "[xSPServiceAppPool]MainServiceAppPool"
        }
        xSPManagedMetaDataServiceApp ManagedMetadataServiceApp
        {  
            Name                 = "Managed Metadata Service Application"
            PsDscRunAsCredential = $SPSetupAccount
            ApplicationPool      = "SharePoint Service Applications"
            DatabaseServer       = $DatabaseServer
            DatabaseName         = "SP_ManagedMetadata"
            DependsOn            = "[xSPServiceAppPool]MainServiceAppPool"
        }
        xSPSearchServiceApp SearchServiceApp
        {  
            Name                  = "Search Service Application"
            DatabaseName          = "SP_Search"
            ApplicationPool       = "SharePoint Service Applications"
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = "[xSPServiceAppPool]MainServiceAppPool"
        }
        xSPBCSServiceApp BCSServiceApp
        {
            Name                  = "BCS Service Application"
            ApplicationPool       = "SharePoint Service Applications"
            DatabaseName          = "SP_BCS"
            DatabaseServer        = $DatabaseServer
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = @('[xSPServiceAppPool]MainServiceAppPool', '[xSPSecureStoreServiceApp]SecureStoreServiceApp')
        }

        #**********************************************************
        # Site Collections
        #
        # This section contains the site collections to provision
        #**********************************************************
        
        xSPSite TeamSite
        {
            Url                      = "http://teams.sharepoint.$DomainName"
            OwnerAlias               = $SPSetupAccount.UserName
            HostHeaderWebApplication = "http://$WebAppUrl"
            Name                     = "Team Sites"
            Template                 = "STS#0"
            PsDscRunAsCredential     = $SPSetupAccount
            DependsOn                = "[xSPWebApplication]HostNameSiteCollectionWebApp"
        }
        xSPSite MySiteHost
        {
            Url                      = "http://$MySiteHostUrl"
            OwnerAlias               = $SPSetupAccount.UserName
            HostHeaderWebApplication = "http://$WebAppUrl"
            Name                     = "My Site Host"
            Template                 = "SPSMSITEHOST#0"
            PsDscRunAsCredential     = $SPSetupAccount
            DependsOn                = "[xSPWebApplication]HostNameSiteCollectionWebApp"
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