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

configuration SQLServer
{
    param( 
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]        $CredSSPDelegates,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential]  $InstallAccount,
		[Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential]  $SPSetupAccount,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [string]        $DomainName,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential]  $domainAdminCredential
    )

	Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xCredSSP
    Import-DscResource -ModuleName xDisk
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xNetworking

    node "localhost"
    {
        xComputer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $domainAdminCredential
        }
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
        xFirewall Firewall
        {
            Name         = "SQLDatabaseEngine"
            DisplayName  = "SQL Server Database Engine"
            DisplayGroup = "SQL Server Rules"
            Ensure       = "Present"
            Access       = "Allow"
            State        = "Enabled"
            Profile      = ("Domain", "Private")
            Direction    = "Inbound"
            LocalPort    = ("1433", "1434")         
            Protocol     = "TCP"
            Description  = "SQL Database engine exception"  
        }
        Script AddDomainAdminSqlSysadmin
        {
            GetScript = Format-DscScriptBlock -replaceValues @{
                "`$USERNAME" = $InstallAccount.UserName
            } -scriptBlock {
                [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
                [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
                $conn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $env:ComputerName
                $conn.applicationName = "PowerShell SMO"
                $conn.ServerInstance = "."
                $conn.StatementTimeout = 0
                $conn.Connect()
                $smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $conn

                $SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $smo,$USERNAME
                $SqlUser.Refresh()
                return @{
                    Username = $InstallAccount.UserName
                    Status = $SqlUser.State.value__
                }
            }
            TestScript = Format-DscScriptBlock -replaceValues @{
                "`$USERNAME" = $InstallAccount.UserName
            } -scriptBlock {
                [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
                [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
                $conn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $env:ComputerName
                $conn.applicationName = "PowerShell SMO"
                $conn.ServerInstance = "."
                $conn.StatementTimeout = 0
                $conn.Connect()
                $smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $conn
                $SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $smo,$USERNAME
                $SqlUser.Refresh()
                $SqlUser.State.value__
                if ($SqlUser.State.value__ -eq 2) {
                    if ($SqlUser.IsMember("sysadmin")) {
                        return $true
                    } else {
                        return $false
                    }
                }
                else {
                    return $false
                }
            }
            SetScript = Format-DscScriptBlock -replaceValues @{
                "`$USERNAME" = $InstallAccount.UserName
            } -scriptBlock {
                [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
                [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
                $conn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $env:ComputerName
                $conn.applicationName = "PowerShell SMO"
                $conn.ServerInstance = "."
                $conn.StatementTimeout = 0
                $conn.Connect()
                $smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $conn
                $SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $smo,$USERNAME
                $SqlUser.Refresh()
                $SqlUser.State.value__
                if ($SqlUser.State.value__ -eq 2) {
                    if ($SqlUser.IsMember("sysadmin")) {
                    } else {
                        $SqlUser.AddToRole("sysadmin")
                    }
                }
                else {
                    $SqlUser.LoginType = 'WindowsUser'
                    $sqlUser.PasswordPolicyEnforced = $false
                    $SqlUser.Create()
                    $SqlUser.AddToRole("sysadmin")
                }
            }
            DependsOn = "[xComputer]DomainJoin"
        }
		Script AddSPSetupSqlSysadmin
        {
            GetScript = Format-DscScriptBlock -replaceValues @{
                "`$USERNAME" = $SPSetupAccount.UserName
            } -scriptBlock {
                [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
                [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
                $conn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $env:ComputerName
                $conn.applicationName = "PowerShell SMO"
                $conn.ServerInstance = "."
                $conn.StatementTimeout = 0
                $conn.Connect()
                $smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $conn

                $SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $smo,$USERNAME
                $SqlUser.Refresh()
                return @{
                    Username = $InstallAccount.UserName
                    Status = $SqlUser.State.value__
                }
            }
            TestScript = Format-DscScriptBlock -replaceValues @{
                "`$USERNAME" = $SPSetupAccount.UserName
            } -scriptBlock {
                [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
                [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
                $conn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $env:ComputerName
                $conn.applicationName = "PowerShell SMO"
                $conn.ServerInstance = "."
                $conn.StatementTimeout = 0
                $conn.Connect()
                $smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $conn
                $SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $smo,$USERNAME
                $SqlUser.Refresh()
                $SqlUser.State.value__
                if ($SqlUser.State.value__ -eq 2) {
                    if ($SqlUser.IsMember("sysadmin")) {
                        return $true
                    } else {
                        return $false
                    }
                }
                else {
                    return $false
                }
            }
            SetScript = Format-DscScriptBlock -replaceValues @{
                "`$USERNAME" = $SPSetupAccount.UserName
            } -scriptBlock {
                [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
                [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
                $conn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $env:ComputerName
                $conn.applicationName = "PowerShell SMO"
                $conn.ServerInstance = "."
                $conn.StatementTimeout = 0
                $conn.Connect()
                $smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $conn
                $SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $smo,$USERNAME
                $SqlUser.Refresh()
                $SqlUser.State.value__
                if ($SqlUser.State.value__ -eq 2) {
                    if ($SqlUser.IsMember("sysadmin")) {
                    } else {
                        $SqlUser.AddToRole("sysadmin")
                    }
                }
                else {
                    $SqlUser.LoginType = 'WindowsUser'
                    $sqlUser.PasswordPolicyEnforced = $false
                    $SqlUser.Create()
                    $SqlUser.AddToRole("sysadmin")
                }
            }
			DependsOn = "[xComputer]DomainJoin"
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

        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }
    }
}
