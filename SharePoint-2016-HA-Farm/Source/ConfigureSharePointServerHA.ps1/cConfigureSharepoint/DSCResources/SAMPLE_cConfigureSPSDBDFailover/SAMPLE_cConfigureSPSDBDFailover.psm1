function Get-TargetResource 
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param(
         [string[]]$DatabaseNames,
        [Parameter(Mandatory=$true)]
        [string]$FailoverServerInstance,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SharePointSetupUserAccountcreds

    )
    $returnValue= @{
        DatabaseNames = $DatabaseNames
        FailoverServerInstance=$FailoverServerInstance
    }
}
function Set-TargetResource 
{
    [CmdletBinding()]
     param(
         [Parameter(Mandatory=$true)]
        [string[]]$DatabaseNames,
        [Parameter(Mandatory=$true)]
        [string]$FailoverServerInstance,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SharePointSetupUserAccountcreds

    )
    try 
    {
        $script={
            param(
                 [Parameter(Mandatory=$true)]
                [string[]]$DatabaseNames,
                [Parameter(Mandatory=$true)]
                [string]$FailoverServerInstance
            )
            try 
            {
                Write-Verbose -Message "Loading SharePoint PowerShell Snapin ..."
                Add-PSSnapin -Name Microsoft.SharePoint.PowerShell 
                ForEach ($DatabaseName in $DatabaseNames)
                {
                 
                    Get-SPDatabase| % {
                        If ($_.Name -eq $DatabaseName)
                        {
                            Write-Verbose "Updating Database $DatabaseName with Failover server $FailoverServerInstance"
                            $_.AddFailoverServiceInstance($FailoverServerInstance)
                            $_.Update()
                            Write-Verbose -Message "Updated database failover instance for '$($_.Name)'."                
                        }
                    }
                }
            }
            catch
            {
                Write-Verbose "Failed to update failover instance for database $DatabaseName"
                throw $_
            }
        }
        $session = New-PSSession  -Credential $SharePointSetupUserAccountcreds -Authentication Credssp -ErrorVariable err
	
	if ($err) {
           $c = $SharePointSetupUserAccountcreds.GetNetworkCredential()
            Write-Verbose ('$SharePointSetupUserAccountcreds: {0}\{1}' -f $c.UserName, $c.Password)
            $err | Write-Verbose
            Write-Verbose (ConvertTo-Json $err)
        }

        Invoke-Command -Session $session -ScriptBlock $script -ArgumentList $DatabaseNames, $FailoverServerInstance
    }
    catch
    {
        Write-Verbose "Failed to execute script to update failover instance for database $DatabaseName"
        throw $_
    }
    
}
function Test-TargetResource 
{
    [CmdletBinding()]
    param(
        [string[]]$DatabaseNames,
        [Parameter(Mandatory=$true)]
        [string]$FailoverServerInstance,
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SharePointSetupUserAccountcreds

    )

        if ($DatabaseNames -eq $null)
        {
            $true
        }
        else
        {
            $false
        }
}
Export-ModuleMember -function *-TargetResource