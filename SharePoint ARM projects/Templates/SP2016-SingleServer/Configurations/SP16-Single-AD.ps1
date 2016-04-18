configuration ADServer
{
    param( 
        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [string]
        $CredSSPDelegates,

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [PSCredential]
        $domainAdminCredential,
        
        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [PSCredential]
        $SafemodeAdministratorPassword,

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [PSCredential]
        $serviceAccountCredential,

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [string]
        $FQDN,

		[Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [string]
		$NetbiosName,

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [string]
        $SPDnsName,

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [string]
        $SPDnsTarget
    ) 

	Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory 
    Import-DscResource -ModuleName xCredSSP 
    Import-DscResource -ModuleName xDnsServer

    node "localhost"
    {
        xCredSSP CredSSPServer 
        { 
            Ensure = "Present" 
            Role = "Server" 
        } 
        xCredSSP CredSSPClient 
        { 
            Ensure = "Present" 
            Role = "Client" 
            DelegateComputers = $CredSSPDelegates
        } 
        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services" 
        }
        WindowsFeature ADRsatToolsInstall 
        { 
            Ensure = "Present" 
            Name = "RSAT-ADDS" 
            DependsOn = "[WindowsFeature]ADDSInstall"
        } 
        WindowsFeature ADAdminCenterInstall 
        { 
            Ensure = "Present" 
            Name = "RSAT-AD-AdminCenter" 
            DependsOn = "[WindowsFeature]ADDSInstall"
        } 
        WindowsFeature ADDSToolsInstall 
        { 
            Ensure = "Present" 
            Name = "RSAT-ADDS-Tools" 
            DependsOn = "[WindowsFeature]ADDSInstall"
        } 
        WindowsFeature ADPowerShellInstall
        {
            Ensure = "Present"
            Name = "RSAT-AD-PowerShell"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }
        xADDomain CreateDomain 
        { 
            DomainName = $FQDN
			DomainNetbiosName = $NetbiosName
            DomainAdministratorCredential = $domainAdminCredential
            SafemodeAdministratorPassword = $SafemodeAdministratorPassword
            DependsOn = "[WindowsFeature]ADPowerShellInstall" 
        }
        xWaitForADDomain DscForestWait 
        {
            DomainName = $FQDN
            DomainUserCredential = $domainAdminCredential 
            RetryCount = 20 
            RetryIntervalSec = 30 
            DependsOn = "[xADDomain]CreateDomain" 
        } 
        xADUser SPFarmServiceAccount
        { 
            DomainName = $FQDN
            DomainAdministratorCredential = $domainAdminCredential 
            UserName = "svcSPFarm" 
            Password = $serviceAccountCredential 
            Ensure = "Present" 
            DependsOn = "[xWaitForADDomain]DscForestWait" 
        }
		xADUser SPSetupAccount
        { 
            DomainName = $FQDN
            DomainAdministratorCredential = $domainAdminCredential 
            UserName = "svcSPSetup" 
            Password = $serviceAccountCredential 
            Ensure = "Present" 
            DependsOn = "[xWaitForADDomain]DscForestWait" 
        }
        xADUser SPWebAppServiceAccount
        { 
            DomainName = $FQDN
            DomainAdministratorCredential = $domainAdminCredential 
            UserName = "svcSPWebApp" 
            Password = $serviceAccountCredential 
            Ensure = "Present" 
            DependsOn = "[xWaitForADDomain]DscForestWait" 
        } 
        xADUser SPServiceAppServiceAccount
        { 
            DomainName = $FQDN
            DomainAdministratorCredential = $domainAdminCredential 
            UserName = "svcSPServiceApp" 
            Password = $serviceAccountCredential 
            Ensure = "Present" 
            DependsOn = "[xWaitForADDomain]DscForestWait" 
        }
        xADUser SPCrawlServiceAccount
        { 
            DomainName = $FQDN
            DomainAdministratorCredential = $domainAdminCredential 
            UserName = "svcSPCrawl" 
            Password = $serviceAccountCredential 
            Ensure = "Present" 
            DependsOn = "[xWaitForADDomain]DscForestWait" 
        }
        xADUser SPProfileSyncServiceAccount
        { 
            DomainName = $FQDN
            DomainAdministratorCredential = $domainAdminCredential 
            UserName = "svcSPProfileSync" 
            Password = $serviceAccountCredential 
            Ensure = "Present" 
            DependsOn = "[xWaitForADDomain]DscForestWait" 
        }
        xADUser SPSuperUserServiceAccount
        { 
            DomainName = $FQDN
            DomainAdministratorCredential = $domainAdminCredential 
            UserName = "svcSPSuperUser" 
            Password = $serviceAccountCredential 
            Ensure = "Present" 
            DependsOn = "[xWaitForADDomain]DscForestWait" 
        }
        xADUser SPSuperReaderServiceAccount
        { 
            DomainName = $FQDN
            DomainAdministratorCredential = $domainAdminCredential 
            UserName = "svcSPReader" 
            Password = $serviceAccountCredential 
            Ensure = "Present" 
            DependsOn = "[xWaitForADDomain]DscForestWait" 
        }
        xDnsARecord SPSitesDns
        {
            Name = $SPDnsName
            Target = $SPDnsTarget
            Zone = $FQDN
            DependsOn = "[xWaitForADDomain]DscForestWait" 
        }
    }
}
