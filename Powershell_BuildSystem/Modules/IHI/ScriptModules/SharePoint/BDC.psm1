
#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # when writing name/value pairs, width of first column
    [int]$script:DefaultCol1Width = 20
    # maximum time (seconds) to wait for a process to complete
    [int]$script:MaxWaitTime = 300
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Install-IHIBDCModel

<#
.SYNOPSIS
Installs a BDC Model and related content source
.DESCRIPTION
Installs a BDC Model and related content source
.PARAMETER ContentSourceName
Content Source Name 
.PARAMETER ServiceContext
Service Context for the BDC Model usually siteurl
.PARAMETER ModelFileFullPath
File path to the model
.PARAMETER LOBSystemSetName
The LOB system name and system instance name 
.PARAMETER RunFullCrawl
Option to run full crawl for content source
.EXAMPLE
Install-IHIBDCModel -ContentSourceName "IMAP" -ServiceContext "http://devweb.ihi.com" -ModelFileFullPath c:\temp\IMAP_Model.bdcm -LOBSystemSetName "IMAP" -RunFullCrawl
Installs BDCModel with those values
#>
function Install-IHIBDCModel {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$ContentSourceName,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$ServiceContext,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$ModelFileFullPath,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$LOBSystemSetName,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$RunFullCrawl
  )
  #endregion
  process {
    #region Parameter validation      
    #region Make sure SharePoint snapin loaded
    # this code only works with IIS 7/WebAdmin module
    if ($false -eq (Confirm-IHISharePointSnapinLoaded)) {
      # error message written in function, no need for me, just return
      return
    }
    #endregion

    #region Confirm ModelFileFullPath exists and has XML
    if ($ModelFileFullPath -eq "") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: ModelFileFullPath is empty."
      return
    }
    if ($false -eq (Test-Path -Path $ModelFileFullPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: ModelFileFullPath not found: $ModelFileFullPath"
      return
    }
    if ($false -eq (Test-Xml -Path $ModelFileFullPath)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: ModelFileFullPath does not contain valid XML: $ModelFileFullPath"
      return
    }
    #endregion

    #region Make sure LOBSystemSetName isn't emtpy
    if ($LOBSystemSetName.Trim() -eq "") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: LOBSystemSetName is only spaces - put in a real value"
      return
    }
    #endregion
    #endregion

    #region Get reference to the SearchApp and MetadataStore and validate
    $SearchApp = $null
    $SearchApp = Get-SPEnterpriseSearchServiceApplication
    if ($SearchApp -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Search Application not found."
      return
    }
    $MetadataStore = $null
    if ($ServiceContext -ne "") {
      # add standard properties to Params hashtable
      [hashtable]$Params = @{ BdcObjectType = "Catalog"; ServiceContext = $ServiceContext }
      $Err = $null
      $MetadataStore = Get-SPBusinessDataCatalogMetadataObject @Params -EV Err
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Get-SPBusinessDataCatalogMetadataObject with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Err")"
        return
      }
    }
    if ($MetadataStore -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Metadata Store not found for ServiceContext: $ServiceContext"
      return
    }
    #endregion

    #region Report information before processing
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ContentSourceName",$ContentSourceName)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ServiceContext",$ServiceContext)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ModelFileFullPath",$ModelFileFullPath)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "LOBSystemSetName",$LOBSystemSetName)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "RunFullCrawl",$RunFullCrawl)
    Remove-IHILogIndentLevel
    #endregion

    #region Install BDC Model
    Add-IHILogIndentLevel
    Write-Host "Install BDC Model"
    Add-IHILogIndentLevel
    if ($MetadataStore -ne $null -and $ModelFileFullPath -ne "") {
      #region Import IMAPBDC Model
      Write-Host "Installing BDC Model"
      Add-IHILogIndentLevel
      # add standard properties to Params hashtable
      [hashtable]$Params = @{ Path = $ModelFileFullPath; Identity = $MetadataStore; PermissionsIncluded = $true; PropertiesIncluded = $true }
      $Err = $null
      $Results = Import-SPBusinessDataCatalogModel @Params -EV Err 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Import-SPBusinessDataCatalogModel with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
        return
      }
      Write-Host "BDC Model Installed"
      Remove-IHILogIndentLevel
      #endregion
    } else {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Error installing BDCModel. :: $($_.Exception.ToString())"
      return
    }
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion

    #region Install Content Source
    Add-IHILogIndentLevel
    Write-Host "Install Content Source"
    Add-IHILogIndentLevel
    #region Get ProxyGroup
    $ProxyGroup = $null
    $Err = $null
    $ProxyGroup = Get-SPServiceApplicationProxyGroup -default -EV Err
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Import-SPBusinessDataCatalogModel with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Err")"
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel;
      return
    }
    #endregion
    $LobSystems = $null
    $LobSystems = @( $LOBSystemSetName,$LOBSystemSetName)
    if ($SearchApp -ne $null -and $ContentSourceName -ne "" -and $ProxyGroup -ne $null -and $LobSystems -ne $null) {
      #region Installing Content Source
      Write-Host "Installing Content Source"
      Add-IHILogIndentLevel
      # add standard properties to Params hashtable
      [hashtable]$Params = @{ Name = $ContentSourceName; SearchApplication = $SearchApp; BDCApplicationProxyGroup = $ProxyGroup; Type = "Business"; LOBSystemSet = $LobSystems }
      $Err = $null
      $Results = New-SPEnterpriseSearchCrawlContentSource @Params -EV Err 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in New-SPEnterpriseSearchCrawlContentSource with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
        return
      }
      Write-Host "Content Source Created"
      Remove-IHILogIndentLevel
      #endregion
    }
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion

    #region Start Crawl
    Add-IHILogIndentLevel
    Write-Host "Start Crawl"
    Add-IHILogIndentLevel
    $ContentSource = $null
    $ContentSource = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $SearchApp | Where { $_.Name -eq $ContentSourceName }
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Start Crawl Get-SPEnterpriseSearchCrawlContentSource"
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
      return
    }
    if ($ContentSource -ne $null -and $ContentSource.CrawlState -eq "Idle") {
      Write-Host "Starting Crawl"
      Add-IHILogIndentLevel
      $ContentSource.StartFullCrawl();
      Write-Host "Crawl Started"
      Remove-IHILogIndentLevel
      Remove-IHILogIndentLevel
      Remove-IHILogIndentLevel
    } else {
      Write-Host "Content Source is null or not idle - crawl not started" -ForegroundColor Yellow
      return
    }
    #endregion
  }
}
Export-ModuleMember -Function Install-IHIBDCModel
#endregion


#region Uninstall-IHIBDCModel

<#
.SYNOPSIS
Removes a BDC Model and related content source, if found (if not, skip, not an error)
.DESCRIPTION
Removes a BDC Model and content source, if found (if not, skip, not an error)
.PARAMETER ContentSourceName
Content Source Name
.PARAMETER ServiceContext
Service Context for the BDC Model usually siteurl
.PARAMETER ModelName
Name of the BDC Model
.EXAMPLE
Uninstall-IHIBDCModel -ContentSourceName "IMAP" -ServiceContext "http://devweb.ihi.com" -ModelName "IMAPBDCModel"
Uninstalls BDCModel with those values
#>
function Uninstall-IHIBDCModel {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$ContentSourceName,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$ServiceContext,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$ModelName
  )
  #endregion
  process {
    #region Parameter validation
    #region Make sure SharePoint snapin loaded
    # this code only works with IIS 7/WebAdmin module
    if ($false -eq (Confirm-IHISharePointSnapinLoaded)) {
      # error message written in function, no need for me, just return
      return
    }
    #endregion
    #endregion

    #region Get reference to the SearchApp, ContentSource and ModelFile
    $SearchApp = $null
    $SearchApp = Get-SPEnterpriseSearchServiceApplication
    if ($SearchApp -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Search Application not found."
      return
    }
    # if ContentSourceName passed, get a reference to it now; if not found
    $ContentSource = $null
    $ContentSource = Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $SearchApp | Where { $_.Name -eq $ContentSourceName }
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Get-SPEnterpriseSearchCrawlContentSource"
      return
    }
    if ($ContentSource -eq $null) {
      Write-Host "$($MyInvocation.MyCommand.Name):: ContentSource not found for: $ContentSourceName" -ForegroundColor Yellow
    }
    $ModelFile = $null
    if ($ModelName -ne "" -and $ServiceContext -ne "") {
      # add standard properties to Params hashtable
      [hashtable]$Params = @{ Name = $ModelName; BdcObjectType = "Model"; ServiceContext = $ServiceContext }
      $Err = $null
      $ModelFile = Get-SPBusinessDataCatalogMetadataObject @Params -EV Err
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Get-SPBusinessDataCatalogMetadataObject with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Err")"
        return
      }
    }
    if ($ModelFile -eq $null) {
      Write-Host "$($MyInvocation.MyCommand.Name):: ModelFile not found not found for Model Name: $ModelName and Service Context: $ServiceContext" -ForegroundColor Yellow
    }
    #endregion

    #region Report information before processing
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ContentSourceName",$ContentSourceName)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ServiceContext",$ServiceContext)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ModelName",$ModelName)
    Remove-IHILogIndentLevel
    #endregion

    #region Remove content source if exists, if not, no error, just don't remove
    Add-IHILogIndentLevel
    Write-Host "Remove Content Source"
    Add-IHILogIndentLevel
    if ($ContentSource -ne $null) {
      Write-Host "Removing Content Source"
      Add-IHILogIndentLevel
      #region Stop ContentSource crawl if not idle
      if ($ContentSource.CrawlState -ne "Idle") {
        Write-Host "Stopping content crawl"
        $StartTime = Get-Date
        $ContentSource.StopCrawl()
        while ($ContentSource.CrawlState -ne "Idle") {
          # check if total time longer than desired max
          if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
            Write-Error -Message "$($MyInvocation.MyCommand.Name):: Time out waiting for crawl to turn to state Idle after stop command; current state: $($ContentSource.CrawlState)"
            Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel;
            return
          }
          Start-Sleep -Seconds 5
        }
      }
      #endregion
      $ContentSource | Remove-SPEnterpriseSearchCrawlContentSource -Confirm:$false
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Remove-SPEnterpriseSearchCrawlContentSource"
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
        return
      }
      Write-Host "Content Source Removed"
      Remove-IHILogIndentLevel
    } else {
      Write-Host "Content Source null - skipping remove step"
    }
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion

    #region Remove BDC Model if it exists, if not, no error, just don't remove
    Add-IHILogIndentLevel
    Write-Host "Remove BDC Model"
    Add-IHILogIndentLevel
    if ($ModelFile -ne $null) {
      Write-Host "Removing BDC Model"
      Add-IHILogIndentLevel
      # add standard properties to Params hashtable
      [hashtable]$Params = @{ Identity = $ModelFile; Confirm = $false }
      $Err = $null
      $Results = Remove-SPBusinessDataCatalogModel @Params -EV Err 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Remove-SPBusinessDataCatalogModel with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
        return
      }
      Write-Host "BDC Model Removed"
      Remove-IHILogIndentLevel
    } else {
      Write-Host "BDC Model null - skipping remove step"
    }
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
  }
}
Export-ModuleMember -Function Uninstall-IHIBDCModel
#endregion

#region Install-IHISecureStoreTargetApp

<#
.SYNOPSIS
Adds a secure store target app if it doesn't already exist
.DESCRIPTION
Adds a secure store target app if it doesn't already exis
.PARAMETER SecureStoreProxyName
The name of the Secure Store Application
.PARAMETER TargetAppName
The name of the Secure Store Target Application
.PARAMETER ContactEmail
The contact email address for the Secure Store Target Application
.PARAMETER UserName
Target Application administrator
.PARAMETER ServiceContext
Service Context for the Target Application usually siteurl
.PARAMETER DBUser
The user name for the windows account that has read access to the DB for the Target App
.PARAMETER DBUserPassword
The password for the windows account that has read access to the DB for the Target App
.EXAMPLE
Install-IHISecureStoreTargetApp -SecureStoreProxyName "Secure Store Service" -TargetAppName "BDCAuth" -ContactEmail "youremail@ihi.org" -UserName "ihi\administratoraccount" -ServiceContext "http://localhost" -DBUser "ihi\DBUser" -DBUserPassword "password"
#>
function Install-IHISecureStoreTargetApp {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$SecureStoreProxyName,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$TargetAppName,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$ContactEmail,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$UserName,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$ServiceContext,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$DBUser,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string]$DBUserPassword


  )
  #endregion
  process {
    #region Parameter validation      
    #region Make sure SharePoint snapin loaded
    # this code only works with IIS 7/WebAdmin module
    if ($false -eq (Confirm-IHISharePointSnapinLoaded)) {
      # error message written in function, no need for me, just return
      return
    }
    #endregion
    #endregion 

    #region Report information before processing
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "SecureStoreProxyName",$SecureStoreProxyName)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "TargetAppName",$TargetAppName)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ContactEmail",$ContactEmail)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "UserName",$UserName)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "ServiceContext",$ServiceContext)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "DBUser",$DBUser)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "DBUserPassword",$DBUserPassword)
    Remove-IHILogIndentLevel
    #endregion

    #region Set secure store fields    
    # Creating Secure Store fields, when using RDB credentials -Type should be changed to UserName and PassWord
    $UserField = New-SPSecureStoreApplicationField ?Name "UserName" -Type WindowsUserName ?Masked:$false
    $PasswordField = New-SPSecureStoreApplicationField ?Name "Password" ?Type WindowsPassword ?Masked:$true
    $Fields = $UserField,$PasswordField
    #endregion

    #region Set credential field values
    # credential field values to set for the target application, when using RDB credentials this will be just the user id  
    $UserCredential = ConvertTo-SecureString $DBUser ?AsPlainText ?Force
    $PasswordCredential = ConvertTo-SecureString $DBUserPassword ?AsPlainText ?Force
    $CredentialValues = $UserCredential,$PasswordCredential

    # credential types, default assuming windows credentials, change it accordingly if you are using RdbCredentials 
    $CredentialTypes = "WindowsUserName","WindowsPassword"
    #endregion

    #region Set admin and users for target app
    # administrator for the secure store target application 
    $Admin = $null
    if ($UserName -ne "") {
      $Admin = New-SPClaimsPrincipal -Identity $UserName -IdentityType WindowsSamAccountName
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in New-SPClaimsPrincipal"
        return
      }
    }

    # The users and groups that are mapped to the credentials defined for this Target Application - All Authenticated Users. 
    $Users = $null
    $Users = New-SPClaimsPrincipal -Identity "c:0(.s|true" -IdentityType EncodedClaim
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in New-SPClaimsPrincipal"
      return
    }
    #endregion

    #region Get reference to the SecureStoreProxy
    $Proxy = $null
    if ($SecureStoreProxyName -ne "") {
      $Proxy = Get-SPServiceApplicationProxy | Where { $_ -match $SecureStoreProxyName }
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Get-SPServiceApplicationProxy"
        return
      }
    }
    if ($Proxy -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Proxy is null."
      return
    }
    #endregion

    #region Get reference to default service context
    $DefaultServiceContext = $null
    if ($ServiceContext -ne "") {
      $DefaultServiceContext = Get-SPSite $ServiceContext | Get-SPServiceContext
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Get-SPSite | Get-SPServiceContext"
        return
      }
    }
    #endregion        

    #region Add Secure Store Target App if it doesn't already exist
    Add-IHILogIndentLevel
    Write-Host "Add Secure Store App"
    if ($ServiceContext -ne "" -and $TargetAppName -ne "") {
      #Check to see if Target App already exists
      Get-SPSecureStoreApplication -Name $TargetAppName -ServiceContext $ServiceContext -ErrorAction SilentlyContinue
      #Secure Store doesn't exist, create it
      if ($? -eq $false -and $TargetAppName -ne "" -and $ContactEmail -ne "") {
        #region Creating Secure Store App
        #create the secure store application         
        # add standard properties to Params hashtable
        Add-IHILogIndentLevel
        Write-Host "Adding Secure Store App"
        Add-IHILogIndentLevel
        [hashtable]$Params = @{ Name = $TargetAppName; FriendlyName = $TargetAppName; ContactEmail = $ContactEmail; ApplicationType = "Group"; TimeoutInMinutes = 5 }
        $Err = $null
        $App = New-SPSecurestoreTargetApplication @Params -EV Err
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in New-SPSecurestoreTargetApplication with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Err")"
          Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
          return
        } else {
          [hashtable]$Params = @{ ServiceContext = $DefaultServiceContext; TargetApplication = $App; Administrator = $Admin; Fields = $Fields; CredentialsOwnerGroup = $Users }
          $Err = $null
          $Results = New-SPSecurestoreApplication @Params -EV Err 2>&1
          if ($? -eq $false) {
            Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in New-SPSecurestoreApplication with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
            Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
            return
          }

        }
      } else {
        #Secure Store already exists, not setting it up
        Write-Host "$($MyInvocation.MyCommand.Name):: Secure Store App already set up for: $TargetAppName" -ForegroundColor Yellow
        Remove-IHILogIndentLevel
        return
      }


    }
    Write-Host "Secure Store Created"
    Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
    #endregion  

    #region Set Credentials
    Add-IHILogIndentLevel
    Write-Host "Set Secure Store Credentials"
    Add-IHILogIndentLevel
    if ($DefaultServiceContext -ne $null -and $TargetAppName -ne "") {
      $SecureApp = Get-SPSecureStoreApplication -ServiceContext $DefaultServiceContext -Name $TargetAppName
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: Error setting credentials. :: $($_.Exception.ToString())"
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
        return

      } else {
        Write-Host "Setting Secure Store Credentials"
        Add-IHILogIndentLevel
        [hashtable]$Params = @{ Identity = $SecureApp; Values = $CredentialValues }
        $Err = $null
        $Results = Update-SPSecurestoreGroupCredentialMapping @Params -EV Err 2>&1
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Update-SPSecurestoreGroupCredentialMapping with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
          Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
          return
        }
        Write-Host "Credentials Set"
        Remove-IHILogIndentLevel
        Remove-IHILogIndentLevel
        Remove-IHILogIndentLevel
      }
    } else {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Error setting credentials. :: $($_.Exception.ToString())"
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
      return
    }
    #endregion    

  }
}
Export-ModuleMember -Function Install-IHISecureStoreTargetApp
#endregion
