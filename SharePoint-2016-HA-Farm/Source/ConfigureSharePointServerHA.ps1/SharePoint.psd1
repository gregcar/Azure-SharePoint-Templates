@{
    AllNodes = @(
        @{
            NodeName = "*"
            DisableIISLoopbackCheck = $true
        },
        @{ 
            NodeName = "sps-app-0"
            ServiceRoles = @{
                WebFrontEnd = $false
                DistributedCache = $false
                AppServer = $true
            }
        },
        @{ 
            NodeName = "sps-app-1"
            ServiceRoles = @{
                WebFrontEnd = $false
                DistributedCache = $false
                AppServer = $true
            }
        },
        @{ 
            NodeName = "sps-web-0"
            ServiceRoles = @{
                WebFrontEnd = $true
                DistributedCache = $true
                AppServer = $false
            }
        },
        @{ 
            NodeName = "sps-web-1"
            ServiceRoles = @{
                WebFrontEnd = $true
                DistributedCache = $true
                AppServer = $false
            }
        }
    )
    NonNodeData = @{
        DomainDetails = @{
            DomainName = "contoso.local"
            NetbiosName = "CONTOSO"
        }
        SQLServer = @{
            ContentDatabaseServer = "sql-0.contoso.local"
            SearchDatabaseServer = "sql-0.contoso.local"
            ServiceAppDatabaseServer = "sql-0.contoso.local"
            FarmDatabaseServer = "sql-0.contoso.local"
        }
        SharePoint = @{
            ProductKey = "INSERT PRODUCT KEY HERE"
            Binaries = @{
                Path = "C:\Binaries\SharePoint"
                Prereqs = @{
                    OfflineInstallDir = "C:\Binaries\SharePoint\PrerequisitesInstallerfiles"
                }
            }
            Farm = @{
                ConfigurationDatabase = "SP_Config"
                Passphrase = "Z^z&Qk5?qMBK+qq9WnzN"
                AdminContentDatabase = "SP_AdminContent"
            }
            DiagnosticLogs = @{
                Path = "F:\ULSLogs"
                MaxSize = 10
                DaysToKeep = 7
            }
            UsageLogs = @{
                DatabaseName = "SP_Usage"
                Path = "F:\UsageLogs"
            }
            StateService = @{
                DatabaseName = "SP_State"
            }
            WebApplications = @(
                @{
                    Name = "SharePoint Sites"
                    DatabaseName = "SP_Content_01"
                    Url = "http://sites.sharepoint.contoso.local"
                    Authentication = "NTLM"
                    Anonymous = $false
                    AppPool = "SharePoint Sites"
                    AppPoolAccount = "CONTOSO\spfarm"
                    SuperUser = "CONTOSO\spfarm"
                    SuperReader = "CONTOSO\spfarm"
                    UseHostNamedSiteCollections = $true
                    ManagedPaths = @(
                        @{
                            Path = "teams"
                            Explicit = $false
                        },
                        @{
                            Path = "personal"
                            Explicit = $false
                        }
                    )
                    SiteCollections = @(
                        @{
                            Url = "http://teams.sharepoint.contoso.local"
                            Owner = "CONTOSO\spfarm"
                            Name = "Team Sites"
                            Template = "STS#0"
                        },
                        @{
                            Url = "http://my.sharepoint.contoso.local"
                            Owner = "CONTOSO\spfarm"
                            Name = "My Sites"
                            Template = "SPSMSITEHOST#0"
                        }
                    )
                }
            )
            UserProfileService = @{
                MySiteUrl = "http://my.sharepoint.contoso.local"
                ProfileDB = "SP_UserProfiles"
                SocialDB = "SP_Social"
                SyncDB = "SP_ProfileSync"
            }
            SecureStoreService = @{
                DatabaseName = "SP_SecureStore"
            }
            ManagedMetadataService = @{
                DatabaseName = "SP_ManagedMetadata"
            }
            BCSService = @{
                DatabaseName = "SP_BCS"
            }
            Search = @{
                DatabaseName = "SP_Search"
            }
        }
    }
}