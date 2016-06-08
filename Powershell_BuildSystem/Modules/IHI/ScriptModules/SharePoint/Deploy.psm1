
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


#region Functions: Disable-IHISharePointFeature

<#
.SYNOPSIS
Disables SharePoint feature, if found (if not, skip, not an error)
.DESCRIPTION
Disables SharePoint feature, if found (if not, skip, not an error)
.PARAMETER FeatureId
Id (guid) of feature
.PARAMETER SiteUrl
Url of site, if feature is site-specific
.EXAMPLE
Disable-IHISharePointFeature -FeatureId <guid> -SiteUrl <web url>
Disables SharePoint feature
#>
function Disable-IHISharePointFeature {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [guid]$FeatureId,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$SiteUrl
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

    #region If passed, make sure SiteUrl points to a valid site (get Site now as well)
    # if SiteUrl passed, get a reference to it now; if not found
    $Site = $null
    if ($SiteUrl -ne "") {
      $Site = Get-SPSite | Where-Object { $_.Url -eq $SiteUrl }
      if ($Site -eq $null) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: Site not found for SiteUrl: $SiteUrl"
        return
      }
    }
    #endregion
    #endregion

    #region Get feature reference; if feature not found, exit gracefully, not an error
    # it's ok if this function is called and the feature isn't installed yet; might be deploying for first time
    $Feature = Get-SPFeature | Where-Object { $_.Id -eq $FeatureId }
    if ($Feature -eq $null) {
      Write-Host "Feature $FeatureId not loaded; skipping disable step"
      return
    }
    #endregion

	#use the first result (when using ALL compatibility there may be more than one feature with same ID in both hives)
	$Feature = @($feature)[0]
	
    #region Report information before processing
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "FeatureId",$FeatureId)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Feature name",$Feature.DisplayName)
    if ($SiteUrl -ne "") {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "SiteUrl",$SiteUrl)
    }
    Remove-IHILogIndentLevel
    #endregion

    #region Disable feature
    Add-IHILogIndentLevel
    Write-Host "Disable feature"
    Add-IHILogIndentLevel
    Write-Host "Check if site currently uses the feature"
    # if feature not being used yet, that's ok, it may not be deployed yet, just display message
    # to determine if a site-scoped feature is enabled you check if the feature appears in the site's Feature list
    # to determine if a farm-scoped feature is enabled you check if the feature appears on the farms Feature list (via ContentService)    
    if (($Site -ne $null) -and (($Site.Features | Where-Object { $_.DefinitionId -eq $Feature.Id }) -eq $null)) {
      Write-Host "Site does not currently use feature" -ForegroundColor Yellow
    } elseif (($Site -eq $null) -and ((([Microsoft.SharePoint.Administration.SPWebService]::ContentService).Features | Where-Object { $_.DefinitionId -eq $Feature.Id }) -eq $null)) {
      Write-Host "Farm does not currently use feature" -ForegroundColor Yellow
    } else {
      Write-Host "Disabling feature"
      Add-IHILogIndentLevel
      [hashtable]$Params = @{ Confirm = $false; ErrorAction = "Stop"; Force = $true }
      if ($Site -ne $null) { $Params.Url = $SiteUrl }
      $Results = $Feature | Disable-SPFeature @Params 2>&1

      # If there were no errors, $Results should be null, also -Force should clear up basic error 
      # situations (feature already disabled) but in case of any other error, capture results and check
      if ($Results -ne $null) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: Error disabling feature $($Feature.DisplayName) with id $FeatureId with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
      }
      # if this is a site-scoped feature then check to make sure it is removed from the site
      if ($Site -ne $null) {
        # IMPORTANT NOTE: if you ever make a change to a SharePoint configuration (like enabling/disabling
        # features), you need to get a fresh reference to any objects; any object in memory will
        # have the old values so, in this case, we need to get a fresh copy of $Site as it's been changed
        # no need to check for $null, we know it exists
        $Site = Get-SPSite | Where-Object { $_.Url -eq $SiteUrl }
        # to be safe, let's wait until feature is disabled for this site before continuing
        # keep looping until $Site.Features DOES NOT APPEAR in the features
        # or until timeout reached
        $StartTime = Get-Date
        while (($Site.Features | Where-Object { $_.DefinitionId -eq $Feature.Id }) -ne $null) {
          # check if total time longer than desired max
          if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
            Write-Error -Message "$($MyInvocation.MyCommand.Name):: Time out error disabling feature $($Feature.DisplayName) with id $FeatureId for url $SiteUrl. Is the url a valid scope for this feature?"
            Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
          }
          Start-Sleep -Seconds 5
          $Site = Get-SPSite | Where-Object { $_.Url -eq $SiteUrl }
        }
      } else {
        # this is a farm-scoped feature; to check if it is disabled, make sure it no longer appears
        # in the Features list of the default ContentService SPWebService so get default ContentService WebService
        $WebService = [Microsoft.SharePoint.Administration.SPWebService]::ContentService
        # to be safe, let's wait until feature is removed from ContentService Features before continuing
        # or until timeout reached
        $StartTime = Get-Date
        while (($WebService.Features | Where-Object { $_.DefinitionId -eq $Feature.Id }) -ne $null) {
          # check if total time longer than desired max
          if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
            Write-Error -Message "$($MyInvocation.MyCommand.Name):: Time out error disabling farm-scoped feature $($Feature.DisplayName) with id $FeatureId for url $SiteUrl. Is the farm a valid scope for this feature?"
            Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
          }
          Start-Sleep -Seconds 5
          $WebService = [Microsoft.SharePoint.Administration.SPWebService]::ContentService
        }
      }
      Write-Host "Feature disabled"
      Remove-IHILogIndentLevel
    }
    Remove-IHILogIndentLevel; Remove-IHILogIndentLevel
    #endregion

    #region Uninstall feature
    Add-IHILogIndentLevel
    Write-Host "Uninstall feature"
    Add-IHILogIndentLevel
    # get fresh reference to feature
    $Feature = Get-SPFeature | Where-Object { $_.Id -eq $FeatureId }
    Write-Host "Uninstalling feature"
    Add-IHILogIndentLevel
    [hashtable]$Params = @{ Confirm = $false; ErrorAction = "Stop"; Force = $true }
    $Results = $Feature | Uninstall-SPFeature @Params 2>&1
    # If there were no errors, $Results should be null, also -Force should clear up basic error
    # situations (feature already disabled) but in case of any other error, capture results and check
    if ($Results -ne $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Error uninstalling feature $($Feature.DisplayName) with id $FeatureId with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
    }
    # to be safe, let's wait until feature is uninstalled entirely keep looping until Get-SPFeature 
    # DOES NOT return the feature or until timeout reached
    $StartTime = Get-Date
    while ((Get-SPFeature | Where-Object { $_.Id -eq $FeatureId }) -ne $null) {
      # check if total time longer than desired max
      if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: Time out error uninstalling feature $($Feature.DisplayName) with id $FeatureId"
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
      }
      Start-Sleep -Seconds 5
    }
    Write-Host "Feature uninstalled"
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
  }
}
Export-ModuleMember -Function Disable-IHISharePointFeature
#endregion


#region Functions: Enable-IHISharePointFeature

<#
.SYNOPSIS
Enables SharePoint feature
.DESCRIPTION
Enables SharePoint feature
.PARAMETER FeatureId
Id (guid) of feature
.PARAMETER SiteUrl
Url of site, if feature is site-specific
.EXAMPLE
Enable-IHISharePointFeature -FeatureId <guid> -SiteUrl <web url>
Enables SharePoint feature
#>
function Enable-IHISharePointFeature {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [guid]$FeatureId,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$SiteUrl
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

    #region If passed, make sure SiteUrl points to a valid site (get Site now as well)
    # if SiteUrl passed, get a reference to it now; if not found
    $Site = $null
    if ($SiteUrl -ne "") {
      $Site = Get-SPSite | Where-Object { $_.Url -eq $SiteUrl }
      if ($Site -eq $null) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: Site not found for SiteUrl: $SiteUrl"
        return
      }
    }
    #endregion
    #endregion

    #region Get feature reference; if feature not found, exit with error
    $Feature = Get-SPFeature | Where-Object { $_.Id -eq $FeatureId }
    if ($Feature -eq $null) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Feature not found by Id: $FeatureId"
      return
    }
	
	#use the first result (when using ALL compatibility there may be more than one feature with same ID in both hives)
	$Feature = @($feature)[0]
	
    #endregion

    #region Report information before processing
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "FeatureId",$FeatureId)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Feature name",$Feature.DisplayName)
    if ($SiteUrl -ne "") {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "SiteUrl",$SiteUrl)
    }
    Remove-IHILogIndentLevel
    #endregion

    #region Enable feature
    Add-IHILogIndentLevel
    Write-Host "Enable feature"
    Add-IHILogIndentLevel
    Write-Host "Check if site currently uses the feature"
    Add-IHILogIndentLevel
    # to determine if a site-scoped feature is enabled you check if the feature appears in the site's Feature list
    # to determine if a farm-scoped feature is enabled you check if the feature appears on the farms Feature list (via ContentService)    
    if (($Site -ne $null) -and (($Site.Features | Where-Object { $_.DefinitionId -eq $Feature.Id }) -ne $null)) {
      Write-Host "Feature already enabled for site - will NOT be re-enabling it"
    } elseif (($Site -eq $null) -and ((([Microsoft.SharePoint.Administration.SPWebService]::ContentService).Features | Where-Object { $_.DefinitionId -eq $Feature.Id }) -ne $null)) {
      Write-Host "Feature already enabled for farm - will NOT be re-enabling it"
    } else {
      Write-Host "Enabling feature"
      [hashtable]$Params = $null
      try {
        #region Details about capturing error
        # Typically we capture errors from cmdlets using $Results = .... 2>&1
        # this doesn't work for a known issue with Enable-SPFeature depending
        # on particular 'incorrect' setting in the profiles ("Users cannot override privacy 
        # while the property is replicable") 
        # In order to capture this error we HAVE to specify -ErrorAction Stop
        # and run in try/catch (and $_ will have the ErrorRecord in the catch block).
        # ErrorVariable does not work, nor does redirecting 2>&1 to a variable for parsing.
        #endregion
        $Params = @{ ErrorAction = "Stop"; Identity = $Feature.DisplayName.toString() }
        if ($Site -ne $null) { $Params.Url = $SiteUrl }
        Enable-SPFeature @Params
      } catch {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: Error enabling feature $($Feature.DisplayName) with id $FeatureId with parameters: $(Convert-IHIFlattenHashtable $Params) :: $($_.Exception.ToString())"
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
      }

      #region Make sure deployed correctly
      # if site-scoped then check to make sure it deployed correctly to the site
      if ($Site -ne $null) {
        # IMPORTANT NOTE: if you ever make a change to a SharePoint configuration (like enabling/disabling
        # features), you need to get a fresh reference to any objects; any object in memory will
        # have the old values in this case, get a fresh copy of $Site as it's been changed
        $Site = Get-SPSite | Where-Object { $_.Url -eq $SiteUrl }
        # loop until feature is enabled (APPEARS in site list)
        # or until timeout reached
        $StartTime = Get-Date
        while (($Site.Features | Where { $_.DefinitionId -eq $Feature.Id }) -eq $null) {
          # check if total time longer than desired max
          if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
            Write-Error -Message "$($MyInvocation.MyCommand.Name):: Time out error waiting to enable site-scoped feature $($Feature.DisplayName) with id $FeatureId for url $SiteUrl. Is the url a valid scope for this feature?"
            Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
          }
          Start-Sleep -Seconds 5
          $Site = Get-SPSite | Where-Object { $_.Url -eq $SiteUrl }
        }
      } else {
        # this is a farm-scoped feature; to check if it is enabled, make sure it appears
        # in the Features list of the default ContentService SPWebService
        # get default ContentService WebService
        $WebService = [Microsoft.SharePoint.Administration.SPWebService]::ContentService
        # to be safe, let's wait until feature is added from ContentService Features before continuing
        # or until timeout reached
        $StartTime = Get-Date
        while (($WebService.Features | Where-Object { $_.DefinitionId -eq $Feature.Id }) -eq $null) {
          # check if total time longer than desired max
          if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
            Write-Error -Message "$($MyInvocation.MyCommand.Name):: Time out error waiting to enable farm-scoped feature $($Feature.DisplayName) with id $FeatureId for url $SiteUrl. Is the farm a valid scope for this feature?"
            Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
          }
          Start-Sleep -Seconds 5
          $WebService = [Microsoft.SharePoint.Administration.SPWebService]::ContentService
        }
      }
      #endregion
      Add-IHILogIndentLevel
      Write-Host "Feature enabled"
      Remove-IHILogIndentLevel
    }
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
  }
}
Export-ModuleMember -Function Enable-IHISharePointFeature
#endregion



#region Functions: Install-IHISharePointWSP

<#
.SYNOPSIS
Adds and installs a SharePoint WSP
.DESCRIPTION
Adds and installs a SharePoint WSP
.PARAMETER Path
Filesystem path to WSP
.PARAMETER Identity
Id of WSP
.PARAMETER GACDeployment
Specify if WSP should be deployed to GAC
.PARAMETER WebApplication
Url of site, if feature is site-specific
.EXAMPLE
Install-IHISharePointWSP -Path <path to WSP> -Identity <guid>
Installs SharePoint WSP
#>
function Install-IHISharePointWSP {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [guid]$Identity,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$GACDeployment,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$WebApplication,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$CompatibilityLevel,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$FullTrustBinDeployment	
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

    #region Make sure WSP Path is valid
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: WSP Path not valid: $Path"
      return
    }
    #endregion
    #endregion

    #region Report information before processing
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Path",$Path)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Identity",$Identity)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "GACDeployment",$GACDeployment)
    if ($WebApplication -ne "") {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "WebApplication",$WebApplication)
    }	
    if ($CompatibilityLevel -ne $null -and $CompatibilityLevel -ne "") {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "CompatibilityLevel",$CompatibilityLevel)
    }
	if ($FullTrustBinDeployment)
	{
		Write-Host $("{0,-$DefaultCol1Width} {1}" -f "FullTrustBinDeployment",$FullTrustBinDeployment)	
	}
    Remove-IHILogIndentLevel
    #endregion

    #region Add solution
    Add-IHILogIndentLevel
    Write-Host "Adding solution"
    Add-IHILogIndentLevel
    [hashtable]$Params = @{ LiteralPath = $Path; ErrorAction = "Stop" }
    $Results = Add-SPSolution @Params 2>&1
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Add-SPSolution with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
    }

    #region Waiting for WSP to be added
    Write-Host "Waiting for solution to be added"
    # loop until WSP name found in Get-SPSolution
    # or until timeout reached
    $StartTime = Get-Date
    $Solution = Get-SPSolution | Where { $_.SolutionId -eq $Identity }
    while ($Solution -eq $null) {
      # check if total time longer than desired max
      if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: Time out error occurred in Add-SPSolution"
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
      }
      Start-Sleep -Seconds 5
      $Solution = Get-SPSolution | Where { $_.SolutionId -eq $Identity }
    }
    # after status changes, still need a brief pause
    Start-Sleep -Seconds 5
    Add-IHILogIndentLevel
    Write-Host "WSP added, elapsed time: $((((Get-Date) - $StartTime).TotalSeconds).ToString()) seconds"
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
    #endregion

    #region Install solution
    Add-IHILogIndentLevel
    Write-Host "Installing solution"
    Add-IHILogIndentLevel
    # add standard properties to Params hashtable
    [hashtable]$Params = @{ Identity = $Identity; GACDeployment = $GACDeployment; Force = $true; ErrorAction = "Stop" }
    # if $WebApplication passed then add it to Params
    if ($WebApplication -ne $null -and $WebApplication.Trim() -ne "") {
      $Params.WebApplication = $WebApplication
    }
    if ($CompatibilityLevel -ne $null -and $CompatibilityLevel -ne "") {
      $Params.CompatibilityLevel = $CompatibilityLevel
    }	
	if ($FullTrustBinDeployment)
	{
		$Params.FullTrustBinDeployment = $FullTrustBinDeployment
	}	
    $Results = Install-SPSolution @Params 2>&1
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Install-SPSolution with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
    }

    #region Waiting for WSP to be installed
    Write-Host "Waiting for solution to be installed"
    # loop until solution deployed = true
    # or until timeout reached
    $StartTime = Get-Date
    $Solution = Get-SPSolution | Where-Object { $_.SolutionId -eq $Identity }
    while ($Solution.Deployed -eq $false) {
      # check if total time longer than desired max
      if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
        [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: Time out error occurred in Install-SPSolution; additional details: " + `
           " LastOperationResult: " + $Solution.LastOperationResult.ToString() + `
           ", LastOperationEndTime: " + $Solution.LastOperationEndTime.ToString() + `
           ", LastOperationDetails: " + $Solution.LastOperationDetails.ToString()
        Write-Error -Message $ErrorMessage
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
      }
      Start-Sleep -Seconds 5
      $Solution = Get-SPSolution | Where-Object { $_.SolutionId -eq $Identity }
    }
    # after status changes, still need a brief pause
    Start-Sleep -Seconds 5
    Add-IHILogIndentLevel
    Write-Host "WSP installed, elapsed time: $((((Get-Date) - $StartTime).TotalSeconds).ToString()) seconds"
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
    #endregion
  }
}
Export-ModuleMember -Function Install-IHISharePointWSP
#endregion


#region Functions: Update-IHISharePointWSP

<#
.SYNOPSIS
Enables feature
.DESCRIPTION
Enables feature
.PARAMETER Path
Filesystem path to WSP
.PARAMETER Identity
Id of WSP
.PARAMETER GACDeployment
Specify if WSP should be deployed to GAC
.EXAMPLE
Update-IHISharePointWSP -Path <path to WSP> -Identity <guid>
Updates SharePoint WSP
#>
function Update-IHISharePointWSP {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [guid]$Identity,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$GACDeployment
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

    #region Make sure WSP Path is valid
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: WSP Path not valid: $Path"
      return
    }

    #region Make sure Solution is installed
    # this only updates solutions; must be installed first
    if ($null -eq (Get-SPSolution | Where { $_.SolutionId -eq $Identity })) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Solution with Id $Identity not installed; use Install-IHISharePointWSP instead"
      return
    }
    #endregion
    #endregion

    #region Report information before processing
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Path",$Path)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Identity",$Identity)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "GACDeployment",$GACDeployment)
    Remove-IHILogIndentLevel
    #endregion

    #region Update solution
    Add-IHILogIndentLevel
    Write-Host "Updating solution"
    Add-IHILogIndentLevel
    [hashtable]$Params = @{ Identity = $Identity; LiteralPath = $Path; GACDeployment = $GACDeployment; Force = $true; ErrorAction = "Stop" }
    $Results = Update-SPSolution @Params 2>&1
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Update-SPSolution with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
    }

    #region Waiting for WSP to be updated
    Write-Host "Waiting for solution to be updated"
    # loop until WSP name found in Get-SPSolution
    # or until timeout reached
    $StartTime = Get-Date
    $Solution = Get-SPSolution | Where { $_.SolutionId -eq $Identity }
    while ($Solution.JobExists -eq $true) {
      # check if total time longer than desired max
      if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: Time out error occurred in Update-SPSolution"
        Remove-IHILogIndentLevel; return
      }
      Start-Sleep -Seconds 5
      $Solution = Get-SPSolution | Where { $_.SolutionId -eq $Identity }
    }
    # after status changes, still need a brief pause
    Start-Sleep -Seconds 5
    Add-IHILogIndentLevel
    Write-Host "WSP updated, elapsed time: $((((Get-Date) - $StartTime).TotalSeconds).ToString()) seconds"
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion
    #endregion
  }
}
Export-ModuleMember -Function Update-IHISharePointWSP
#endregion


#region Functions: Uninstall-IHISharePointWSP

<#
.SYNOPSIS
Uninstalls a SharePoint WSP
.DESCRIPTION
Uninstalls a SharePoint WSP
.PARAMETER Identity
Id of WSP
.PARAMETER WebApplication
Url of site, if feature is site-specific
.EXAMPLE
Uninstall-IHISharePointWSP -Identity <guid> -WebApplication <web url>
Uninstalls SharePoint WSP
#>
function Uninstall-IHISharePointWSP {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [guid]$Identity,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$WebApplication
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

    #region Make sure Solution is installed
    # this uninstalls a solution; must be installed first
    if ($null -eq (Get-SPSolution | Where { $_.SolutionId -eq $Identity })) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Solution with Id $Identity not installed; use Install-IHISharePointWSP instead"
      return
    }
    #endregion
    #endregion

    #region Report information before processing
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Identity",$Identity)
    if ($WebApplication -ne "") {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "WebApplication",$WebApplication)
    }
    Remove-IHILogIndentLevel
    #endregion

    #region Uninstalling solution
    Add-IHILogIndentLevel
    Write-Host "Uninstalling solution"
    Add-IHILogIndentLevel
    # get reference to the solution - we know it exists because we checked above
    $Solution = Get-SPSolution | Where { $_.SolutionId -eq $Identity }
    Write-Host "Uninstalling solution: $($Solution.Name)"
    Add-IHILogIndentLevel
    # make sure it is Deployed, if it isn't, just skip the uninstall step
    if ($Solution.Deployed -eq $false) {
      # not deployed, just report
      Write-Host "Solution $($Solution.Name) id $Identity is not deployed; skipping uninstall step"
    } else {
      # before attempting to uninstall the solution, make sure no jobs
      # associated with this solution are running
      # if so, wait for it to complete (but time out if it takes too long)
      Write-Host "Waiting for jobs to complete before attempting to uninstall"
      $StartTime = Get-Date
      while ($Solution.JobExists -eq $true) {
        # check if total time longer than desired max
        if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: Time out error waiting for jobs to complete before uninstall"
          Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
        }
        Start-Sleep -Seconds 5
        $Solution = Get-SPSolution | Where { $_.SolutionId -eq $Identity }
      }
      # after status changes, still need a brief pause
      Start-Sleep -Seconds 5
      Add-IHILogIndentLevel
      Write-Host "Jobs no longer running, elapsed time: $((((Get-Date) - $StartTime).TotalSeconds).ToString()) seconds"
      Remove-IHILogIndentLevel
      # now uninstall solution
      Write-Host "Uninstalling solution"
      # add standard properties to Params hashtable
      [hashtable]$Params = @{ Identity = $Identity; Confirm = $false; ErrorAction = "Stop" }
      # if $WebApplication passed then add it to Params
      if ($WebApplication -ne $null -and $WebApplication.Trim() -ne "") {
        $Params.WebApplication = $WebApplication
      }
      $Results = Uninstall-SPSolution @Params 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Uninstall-SPSolution with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
      }

      Add-IHILogIndentLevel
      Write-Host "Waiting for solution $Identity to be uninstalled"
      $StartTime = Get-Date
      while ($Solution.Deployed -eq $true) {
        # check if total time longer than desired max
        if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
          [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: Time out error occurred while waiting to uninstall solution; additional details: " + `
             " LastOperationResult: " + $Solution.LastOperationResult.ToString() + `
             ", LastOperationEndTime: " + $Solution.LastOperationEndTime.ToString() + `
             ", LastOperationDetails: " + $Solution.LastOperationDetails.ToString()
          Write-Error -Message $ErrorMessage
          Add-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
        }
        Start-Sleep -Seconds 5
        $Solution = Get-SPSolution | Where { $_.SolutionId -eq $Identity }
      }
      # after status changes, still need a brief pause
      Add-IHILogIndentLevel
      Write-Host "Solution uninstalled, elapsed time: $((((Get-Date) - $StartTime).TotalSeconds).ToString()) seconds"
      Remove-IHILogIndentLevel
      Remove-IHILogIndentLevel
    }
    Remove-IHILogIndentLevel
    Remove-IHILogIndentLevel
    #endregion

    #region Remove solution
    Write-Host "Removing solution"
    Add-IHILogIndentLevel
    # now attempt to remove the solution if Deployed = false
    if ($Solution.Deployed -eq $true) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: Solution $Identity is still deployed but should not be by now"
      Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
    } else {
      # before attempting to remove the solution, make sure no jobs
      # associated with this solution are running
      # if so, wait for it to complete (but time out if it takes too long)
      Write-Host "Waiting for jobs to complete before attempting to remove"
      $StartTime = Get-Date
      while ($Solution.JobExists -eq $true) {
        # check if total time longer than desired max
        if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: Time out error waiting for jobs to complete before remove"
          Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
        }
        Start-Sleep -Seconds 5
        $Solution = Get-SPSolution | Where { $_.SolutionId -eq $Identity }
      }
      # after status changes, still need a brief pause
      Start-Sleep -Seconds 5
      Add-IHILogIndentLevel
      Write-Host "Jobs no longer running, elapsed time: $((((Get-Date) - $StartTime).TotalSeconds).ToString()) seconds"
      Remove-IHILogIndentLevel

      #region Remove solution
      Write-Host "Removing solution"
      Add-IHILogIndentLevel
      # add standard properties to Params hashtable
      [hashtable]$Params = @{ Identity = $Identity; Confirm = $false; ErrorAction = "Stop" }
      $Results = Remove-SPSolution @Params 2>&1
      if ($? -eq $false) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred in Remove-SPSolution with parameters: $(Convert-IHIFlattenHashtable $Params) :: $("$Results")"
        Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
      }
      Write-Host "Waiting for solution to be removed"
      $StartTime = Get-Date
      while ($Solution -ne $null) {
        # check if total time longer than desired max
        if (((Get-Date) - $StartTime).TotalSeconds -gt $MaxWaitTime) {
          [string]$ErrorMessage = "$($MyInvocation.MyCommand.Name):: Time out error occurred while waiting to remove solution; additional details: " + `
             " LastOperationResult: " + $Solution.LastOperationResult.ToString() + `
             ", LastOperationEndTime: " + $Solution.LastOperationEndTime.ToString() + `
             ", LastOperationDetails: " + $Solution.LastOperationDetails.ToString()
          Write-Error -Message $ErrorMessage
          Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; Remove-IHILogIndentLevel; return
        }
        Start-Sleep -Seconds 5
        $Solution = Get-SPSolution | Where { $_.SolutionId -eq $Identity }
      }
      # after status changes, still need a brief pause
      Add-IHILogIndentLevel
      Write-Host "Solution removed, elapsed time: $((((Get-Date) - $StartTime).TotalSeconds).ToString()) seconds"
      Remove-IHILogIndentLevel
      Remove-IHILogIndentLevel
      Remove-IHILogIndentLevel
      Remove-IHILogIndentLevel
      #endregion
    }
    #endregion
  }
}
Export-ModuleMember -Function Uninstall-IHISharePointWSP
#endregion


#region Functions: Start-IHISharePointServices, Stop-IHISharePointServices
# Using this post as a reference for the order of stopping/restarting:
#   http://blogs.msdn.com/emberger/archive/2009/11/16/stop-and-go-with-sharepoint-2010-on-your-workstation.aspx

<#
.SYNOPSIS
Starts SharePoint-related services for a deployment across a farm
.DESCRIPTION
Starts SharePoint-related services for a deployment across a farm. Starts these
services in this order: iisadmin, w3svc, SPAdminV4, SPTraceV4, SPTimerV4
.PARAMETER Servers
List of servers in farm
.EXAMPLE
Start-IHISharePointServices -Servers DEVSPRADM
Starts SharePoint-related services on DEVSPRADM
#>
function Start-IHISharePointServices {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string[]]$Servers
  )
  #endregion
  process {
    #region Parameter validation
    # make sure shell running as administrator before restarting changing service state
    if ($false -eq (Test-IHIIsShellAdministrator)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: PowerShell needs to be running as Administrator in order to start SharePoint services"
      return
    }
    #endregion

    # start a service by Name, not DisplayName
    # can't stop this service: OSearch14
    $CompleteServicesListInOrder = "iisadmin","w3svc","SPAdminV4","SPTraceV4","SPTimerV4"
    [string]$Server = $null
    [string]$ServiceName = $null

    # loop through each server and start services on each server
    Write-Host "Starting SharePoint services on servers: $Servers"
    $Servers | ForEach-Object {
      Add-IHILogIndentLevel
      $Server = $_
      Write-Host "Starting SharePoint services on: $Server"
      $CompleteServicesListInOrder | ForEach-Object {
        Add-IHILogIndentLevel
        $ServiceName = $_
        $Service = Get-Service -ComputerName $Server | Where { $_.Name -eq $ServiceName }
        # first check if service exists
        if ($Service -eq $null) {
          Write-Host "Service $ServiceName does not exist"
        } elseif ($Service.Status -eq "Running") {
          Write-Host "Service $ServiceName is already running; skipping"
        } else {
          Write-Host "Starting service $ServiceName"
          $Service.Start()
          $Service.WaitForStatus("Running")
          # wait a few seconds for it to start entirely
          Start-Sleep -Seconds 2
        }
        Remove-IHILogIndentLevel
      }
      Remove-IHILogIndentLevel
    }
  }
}
Export-ModuleMember -Function Start-IHISharePointServices


<#
.SYNOPSIS
Stops SharePoint-related services for a deployment across a farm
.DESCRIPTION
Stops SharePoint-related services for a deployment across a farm. Stops these
services in this order: SPTimerV4, SPTraceV4, SPAdminV4, w3svc, iisadmin
.PARAMETER Servers
List of servers in farm
.EXAMPLE
Stop-IHISharePointServices -Servers DEVSPRADM
Stops SharePoint-related services on DEVSPRADM
#>
function Stop-IHISharePointServices {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string[]]$Servers
  )
  #endregion
  process {
    #region Parameter validation
    # make sure shell running as administrator before restarting changing service state
    if ($false -eq (Test-IHIIsShellAdministrator)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: PowerShell needs to be running as Administrator in order to start SharePoint services"
      return
    }
    #endregion

    # Stop a service by Name, not DisplayName
    # can't stop this service: OSearch14
    $CompleteServicesListInOrder = "SPTimerV4","SPTraceV4","SPAdminV4","w3svc","iisadmin"
    [string]$Server = $null
    [string]$ServiceName = $null

    # loop through each server and stop services on each server
    Write-Host "Stopping SharePoint services on servers: $Servers"
    $Servers | ForEach-Object {
      Add-IHILogIndentLevel
      $Server = $_
      Write-Host "Stopping SharePoint services on: $Server"
      $CompleteServicesListInOrder | ForEach-Object {
        Add-IHILogIndentLevel
        $ServiceName = $_
        $Service = Get-Service -ComputerName $Server | Where { $_.Name -eq $ServiceName }
        # first check if service exists
        if ($Service -eq $null) {
          Write-Host "Service $ServiceName does not exist"
        } elseif ($Service.Status -eq "Stopped") {
          Write-Host "Service $ServiceName not currently running; skipping"
        } else {
          Write-Host "Stopping service $ServiceName"
          $Service.Stop()
          $Service.WaitForStatus("Stopped")
          # wait a few seconds for it to stop entirely
          Start-Sleep -Seconds 2
        }
        Remove-IHILogIndentLevel
      }
      Remove-IHILogIndentLevel
    }
  }
}
Export-ModuleMember -Function Stop-IHISharePointServices
#endregion


#region Functions: Start-IHISharePointWebAppPools
# The basis for much of this is so varied I wish I could note them all but I can't
# just a general thanks here!

<#
.SYNOPSIS
Starts the SharePoint-related WebApp Pools if they are stopped
.DESCRIPTION
Starts the SharePoint-related WebApp Pools if they are stopped after a deploy
.PARAMETER Servers
List of Servers in the farm
.PARAMETER AppPools
List of App Pools to check
.EXAMPLE
Start-IHISharePointWebAppPools -Servers DEVSPRADM -AppPools "SharePoint Web Services Root", "SPRINGS"
Starts the SharePoint-related WebApp Pools on DEVSPRADM -AppPools "SharePoint Web Services Root", "SPRINGS"
#>
function Start-IHISharePointWebAppPools {
  #region Function parameters
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string[]]$Servers,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [string[]]$AppPools
  )
  #endregion
  process {
    #region Parameter validation
    # make sure shell running as administrator before restarting changing service state
    if ($false -eq (Test-IHIIsShellAdministrator)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: PowerShell needs to be running as Administrator in order to start SharePoint services"
      return
    }
    #endregion
    
    # Check WebApp Pools by name
    # $AppPools = "SharePoint Web Services Root", "SPRINGS", "SecurityTokenServiceApplicationPool", "SharePoint Central Administration v4"
    [string]$Server = $null
    [string]$WebAppPoolName = $null
    
    # Should probably just exit out of here in case the Server list is NULL
    if ( ($Servers -eq $null) -and ($AppPools = $null) ) {
      # Then lets just skip this either its not set or something went wrong
      Write-Host "Since the Server List is null the Web App Pool restarts are being skipped."
    } else {
      # loop through each server and check webapp pools on each server
      Write-Host "Checking SharePoint web app pools on servers: $Servers"
      $Servers | ForEach-Object {
        Add-IHILogIndentLevel
        $Server = $_
        Write-Host "Checking SharePoint web app pools on: $Server"
        $AppPools | ForEach-Object {
          Add-IHILogIndentLevel
          $WebAppPoolName = $_
          if ((($Server -like "*WEB*") -or ($Server -like "*QRY*") -or ($Server -like "*WWW*") -or ($Server -like "*002*")) -and ($WebAppPoolName -eq "SharePoint Central Administration v4")) {
            Write-Host "The $WebAppPoolName does not exist on $Server so skipping it."
            # Since this Web App Pool does not exist here let's skip it
            Remove-IHILogIndentLevel
            return
          }
          if ((($Server -like "*QRY*") -or ($Server -like "*001*") -or ($Server -like "*002*")) -and (($WebAppPoolName -eq "SPRINGS") -or ($WebAppPoolName -eq "Sharepoint - springs.ihi.org80"))) {
            Write-Host "The $WebAppPoolName does not exist on $Server so skipping it."
            # Since this Web App Pool does not exist here let's skip it
            Remove-IHILogIndentLevel
            return
          }
          $state = (Invoke-Command -ComputerName $Server -ConfigurationName "Microsoft.SharePoint.PowerShell" { param($ap) Import-Module WebAdministration; Get-WebAppPoolState $ap} -Args $WebAppPoolName).Value
          # check if app pool is stopped
          if ($state -eq "Stopped") {
            Write-Host "The $WebAppPoolName on $Server is $state, starting the app pool."
            gwmi -namespace "root\webadministration" -ComputerName $Server -Authentication 6 -Query "select * from applicationpool where name='$WebAppPoolName'"| Invoke-WmiMethod -Name start -ErrorAction SilentlyContinue
            # wait a few seconds for it to start up
            Start-Sleep -Seconds 2
          } else {
            Write-Host "The $WebAppPoolName on $Server is $state."
          }
          Remove-IHILogIndentLevel
        }
        Remove-IHILogIndentLevel
      }
    }
  }
}
Export-ModuleMember -Function Start-IHISharePointWebAppPools
#endregion

