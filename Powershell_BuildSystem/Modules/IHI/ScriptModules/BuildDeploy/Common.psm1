#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Get-IHIApplicationConfigFile

<#
.SYNOPSIS
Returns a file reference for a given application name
.DESCRIPTION
Returns a file reference for a given application name.  If no files are
found for that name, returns $null.  If multiple files are found with the
same name, an error is written and $null is returned.
.PARAMETER ApplicationName
Application name
.EXAMPLE
Get-IHIApplicationConfigFile -ApplicationName Extranet
Returns [System.IO.FileSystemInfo] object for Extranet.xml application file
#>
function Get-IHIApplicationConfigFile {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName
  )
  #endregion
  process {
    $ConfigFileName = Get-IHIApplicationConfigFileName -ApplicationName $ApplicationName
    $ConfigFile = Get-ChildItem -Path $($Ihi:BuildDeploy.ApplicationConfigsRootFolder) -Recurse | Where-Object { $_.Name -eq $ConfigFileName }
    # if no files found, just return null
    if ($ConfigFile -ne $null) {
      # if multiple items found, this is an error! set $ConfigFile to $null and write and error
      # note: if only one item found, type is System.IO.FileInfo, otherwise it's an object[] (multiple)
      if ($ConfigFile -isnot [System.IO.FileInfo]) {
        Write-Error -Message "$($MyInvocation.MyCommand.Name):: ApplicationName $ApplicationName matches multiple files: $($ConfigFile | Select -ExpandProperty FullName) - fix this!"
        $ConfigFile = $null
        return
      }
    }
    # return $ConfigFile, even if null
    $ConfigFile
  }
}
Export-ModuleMember -Function Get-IHIApplicationConfigFile
#endregion


#region Functions: Get-IHIApplicationConfigFileName

<#
.SYNOPSIS
Returns the name of the config file for an application
.DESCRIPTION
Returns the name of the config file for an application.  Just adds ".xml"
to application name
.PARAMETER ApplicationName
Application name
.EXAMPLE
Get-IHIApplicationConfigFileName -ApplicationName Extranet
Returns: Extranet.xml
#>
function Get-IHIApplicationConfigFileName {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName
  )
  #endregion
  process {
    $ApplicationName + ".xml"
  }
}
Export-ModuleMember -Function Get-IHIApplicationConfigFileName
#endregion


#region Functions: Get-IHIApplicationNames

<#
.SYNOPSIS
Returns the names of all of the applications
.DESCRIPTION
Returns the names of all of the applications found under the BuildDeploy
ApplicationConfigsRootFolder folder, by default, or under ConfigRootPath if specified 
.PARAMETER ConfigRootPath
Optional root to look for configuration files
.EXAMPLE
Get-IHIApplicationNames
Returns string array: Agility,Agility_Help,AllDBs_Common_Proc,CertificateCenter,...
.EXAMPLE
Get-IHIApplicationNames -ConfigRootPath C:\IHI_MAIN\trunk\PowerShell\Main\BuildDeploy\Configs
Returns string array: Agility,Agility_Help,AllDBs_Common_Proc,CertificateCenter,...
#>
function Get-IHIApplicationNames {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$ConfigRootPath
  )
  #endregion
  process {
    #region Parameter validation
    if ($Ihi:BuildDeploy.ApplicationConfigsRootFolder -eq $null -or $Ihi:BuildDeploy.ApplicationConfigsRootFolder.Trim() -eq "") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: BuildDeploy.ApplicationConfigsRootFolder is null or empty"
      return
    }
    if ($false -eq (Test-Path -Path $Ihi:BuildDeploy.ApplicationConfigsRootFolder)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: BuildDeploy.ApplicationConfigsRootFolder $($Ihi:BuildDeploy.ApplicationConfigsRootFolder) not found"
      return
    }
    # if $ConfigRootPath passed then must exist
    if (($ConfigRootPath -ne "") -and ($false -eq (Test-Path -Path $ConfigRootPath))) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: ConfigRootPath $ConfigRootPath not found"
      return
    }
    #endregion

    #region Get xml files and remove extension
    [string]$Extension = ".xml"
    [object[]]$Files = $null
    [object[]]$FilesNoExtension = $null
    #region Get files
    [string]$PathToCheck = $null
    if ($ConfigRootPath -ne "") {
      $PathToCheck = $ConfigRootPath
    } else {
      $PathToCheck = $Ihi:BuildDeploy.ApplicationConfigsRootFolder
    }
    $Files = Get-ChildItem -Path $PathToCheck -Recurse | Where-Object { $_.Extension -eq $Extension } | Select -ExpandProperty Name
    #endregion
    # for each file, remove extension and add to $FilesNoExtension
    if ($Files -ne $null) {
      $Files | ForEach-Object {
        $FilesNoExtension +=,($_.Substring(0,($_.Length - $Extension.Length)))
      }
      # now sort them
      $FilesNoExtension = $FilesNoExtension | Sort-Object
    }
    # now return them
    $FilesNoExtension
    #endregion
  }
}
Export-ModuleMember -Function Get-IHIApplicationNames
#endregion


#region Functions: Get-IHIApplicationPackageFolderName

<#
.SYNOPSIS
Returns the name of the application package folder
.DESCRIPTION
Returns the name of the application package folder,i.e <name>_<version>
.PARAMETER ApplicationName
Name of application
.PARAMETER Version
Version of application build package
.EXAMPLE
Get-IHIApplicationPackageFolderName -ApplicationName Extranet -Version 9876
Returns: Extranet_9876
#>
function Get-IHIApplicationPackageFolderName {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Version
  )
  #endregion
  process {
    $ApplicationName + "_" + $Version
  }
}
Export-ModuleMember -Function Get-IHIApplicationPackageFolderName
#endregion


#region Functions: Get-IHIApplicationVersionFileName

<#
.SYNOPSIS
Returns the name of the version file for an application
.DESCRIPTION
Returns the name of the version file for an application.  Just adds "_version.txt"
to application name
.PARAMETER ApplicationName
Name of application
.EXAMPLE
Get-IHIApplicationVersionFileName -ApplicationName Extranet
Returns: Extranet_version.txt
#>
function Get-IHIApplicationVersionFileName {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName
  )
  #endregion
  process {
    $ApplicationName + "_version.txt"
  }
}
Export-ModuleMember -Function Get-IHIApplicationVersionFileName
#endregion


#region Functions: Get-IHIAppVersionReleasePackageFolder

<#
.SYNOPSIS
Returns a release folder path for an application/version pair
.DESCRIPTION
Returns a release folder path for an application/version pair.  It only
returns what the path should be; it does not validate that this folder
exists.
.PARAMETER ApplicationName
Name of application
.PARAMETER Version
Version of application build package
.EXAMPLE
Get-IHIAppVersionReleasePackageFolder -ApplicationName Extranet -Version 9876
Returns: \\ENGBUILD.IHI.COM\Releases\Extranet_9876
#>
function Get-IHIAppVersionReleasePackageFolder {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationName,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Version
  )
  #endregion
  process {
    #region Validate the root BuildDeploy.ReleasesFolder folder
    if ($Ihi:BuildDeploy.ReleasesFolder -eq $null -or $Ihi:BuildDeploy.ReleasesFolder.Trim() -eq "") {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: BuildDeploy.ReleasesFolder is null or empty"
      return
    }
    if ($false -eq (Test-Path -Path $Ihi:BuildDeploy.ReleasesFolder)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: BuildDeploy.ReleasesFolder $($Ihi:BuildDeploy.ReleasesFolder) not found; are you on the IHI network?"
      return
    }
    #endregion

    # folder is application/version located under releases folder
    Join-Path -Path $Ihi:BuildDeploy.ReleasesFolder -ChildPath (Get-IHIApplicationPackageFolderName -ApplicationName $ApplicationName -Version $Version)
  }
}
Export-ModuleMember -Function Get-IHIAppVersionReleasePackageFolder
#endregion



#region Functions: Export-IHIApplicationConfigFiles

<#
.SYNOPSIS
Exports application configuration files to local temp folder
.DESCRIPTION
Exports application configuration files to local temp folder
.PARAMETER LocalExportPath
Name of local directory into which the Configs directory will be exported
.EXAMPLE
Export-IHIApplicationConfigFiles -LocalExportPath C:\Temp\ExportedConfigs
Exports the HEAD revision of all of the Build Deploy Configuration files so that
you end up with a C:\Temp\ExportedConfigs\Configs directory.
#>
function Export-IHIApplicationConfigFiles {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LocalExportPath
  )
  #endregion
  process {
    #region Get Head Repository Version, and use it if Version passed is null
    [int]$Version = Get-IHIRepositoryHeadVersion -EV Err
    if ($Err -ne $null) {
        $Err | Write-Error
        [string]$ErrorMessage = "Error attempting to get repository head version"
        Write-Error -Message $ErrorMessage
        $Success = $false
    }
    #endregion
    #region Export application config files
    Write-Host "Fetching latest application config files from the repository into $LocalExportPath"
    Add-IHILogIndentLevel
    Export-IHIRepositoryContent -Version $Version -UrlPath $Ihi:BuildDeploy.ApplicationConfigsRootUrlPath -LocalPath $LocalExportPath
    Remove-IHILogIndentLevel
    #endregion
  }
}
Export-ModuleMember -Function Export-IHIApplicationConfigFiles
#endregion

#region Functions: Analyze-IHIApplicationConfigFiles
<#
.SYNOPSIS
Analyzes application configuration files for source paths and notification emails
.DESCRIPTION
Analyzes application configuration files for source paths and notification emails
.PARAMETER LocalApplicationConfigsPath
Name of local directory containing the Build Deploy Application Configs
.EXAMPLE
Analyze-IHIApplicationConfigFiles -LocalApplicationConfigsPath C:\Temp\ExportedConfigs\Configs
Returns: A hashtable containing all applications and key information about them:
         ApplicationName
         FileName
         FileFullName
         NotificationEmails
         SvnProjectPaths
#>
function Analyze-IHIApplicationConfigFiles {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LocalApplicationConfigsPath
  )
  #endregion
  process {
    #region Parse application config files for SVN path and notification email information
    Write-Host "Parse application files for SVN path and notification email information"
    $ConfigFiles = Get-ChildItem -Path $LocalApplicationConfigsPath -Recurse -Filter *.xml
    $ConfigFiles | ForEach-Object {
      $FileContent = Get-Content -Path $_.FullName
      if ($FileContent -match 'Export-IHIRepositoryContent') {
        [hashtable]$MatchInfo = @{}
        $MatchInfo.ApplicationName = $_.BaseName.ToUpper()
        $MatchInfo.FileName = $_.Name
        $MatchInfo.FileFullName = $_.FullName
        [string[]]$MatchingPaths = $FileContent | Select-String -Pattern 'Export-IHIRepositoryContent.*' -AllMatches | ForEach-Object {
          $_.matches | ForEach-Object {
            $MatchingTextLine = $_.value
            $MatchingTextLine -match '"(/trunk.*)" ' > $null
            $matches[1]
          }
        }
        $MatchInfo.SVNProjectPaths = $MatchingPaths
        [xml]$ContentXml = [xml]$FileContent
        $MatchInfo.NotificationEmails = [string[]]($ContentXml.Application.General.NotificationEmails.Email | ForEach-Object { $_ })
        [hashtable]$AppConfigXmlMatchData.$($MatchInfo.ApplicationName) = $MatchInfo
      }
    }    
    #region Return parsed application config data
    $AppConfigXmlMatchData
    #endregion
    #endregion
  }
}
Export-ModuleMember -Function Analyze-IHIApplicationConfigFiles
#endregion


#region Functions: TabExpansion

#region Back up existing TabExpansion function to TabExpansion_Orig
# Back up existing TabExpansion function to TabExpansion_Orig
# so can be reused later if not doing IHI-build/deploy related expansion.
# This must be done in-line when module loads, not inside TabExpansion,
# as the original function will no longer exist.
# This only has to be done for version 2 of PowerShell, v3 "just works" (not sure how)
if ($Host.Version.MajorRevision -eq 2) {
  $TE = Get-Content Function:\TabExpansion
  Set-Item Function:\global:TabExpansion_Orig -Value $TE
}
#endregion


<#
.SYNOPSIS
Enables tab cycling/completion for: build, deploy, version
.DESCRIPTION
Enables tab cycling/completion for: build, deploy, version
When typing: build <tab> it completes application names
When typing: deploy <tab> it completes application names
When typing: deploy [application name] <tab> it completes application version
When typing: deploy [application name] [version] <tab> it completes environment name
When typing: version <tab> it completes application names
When typing: apphistory <tab> it completes application names
When typing: deployps <tab> it completes PowerShell version
When typing: deployps [version] <tab> it completes environment name
When typing: releasenotes <tab> it completes application names
When typing: releasenotes [application name] it completes application version
Of course you can fill in partial names:
build ex<tab> cycles/completes Extranet and Extranet_Help
.PARAMETER Line
String line
.PARAMETER LastWord
Last token in line
.EXAMPLE
TabExpansion -Line <line> -LastWorld
No need for example - runs TabExpansion automatically
#>
function global:TabExpansion {
  #region Function parameters
  [CmdletBinding()]
  param($Line,$LastWord)
  #endregion
  process {
    # commands processed by IHI tab expansion
    [string]$IhiCommands = "build|deploy|version|deployps|releasenotes|apphistory"
    # get list of current valid application names
    [string[]]$ValidAppNames = Get-IHIApplicationNames
    # get all tokens in line
    [string[]]$Tokens = $Line.Trim().ToUpper().Split(" ")

    # if IHI-build/deploy/gav command specified
    if ($Tokens[0] -inotmatch $IhiCommands) {
      # call original TabExpansion command
      TabExpansion_Orig $Line $LastWord
    } else {
      switch ($Tokens[0]) {
        { "build" -contains $Tokens[0] } {
          # if only one token and space after first token, show full build app names list
          # if two tokens and $LastWord is not "", show build app names that match 2nd item
          # if two tokens and $LastWord is "", they entered a full second param, a full build app name, so ignore
          # more than two, ignore
          if ($Tokens.Count -eq 1 -and $LastWord -eq "") {
            $ValidAppNames
          } elseif ($Tokens.Count -eq 2 -and $LastWord -ne "") {
            $ValidAppNames | Where-Object { $_ -match "^$LastWord" }
          } else {
            # return "" so tab expansion stops running after last valid param
            ""
          }
          break
        }
        { "deploy" -contains $Tokens[0] } {
          # if only one token and space after first token, show full deploy app names list
          # if two tokens and $LastWord is not "", show deploy app names that match 2nd item
          # if two tokens and $LastWord is "", 
          #   check to make sure it's a valid app name
          #     if valid, get list of application verion numbers
          # if two tokens and $LastWord is NOT ""
          #   check to make sure it's a valid app name
          #     if valid, do match of existing verion numbers
          if ($Tokens.Count -eq 1 -and $LastWord -eq "") {
            $ValidAppNames
          } elseif ($Tokens.Count -eq 2 -and $LastWord -ne "") {
            $ValidAppNames | Where-Object { $_ -match "^$LastWord" }
          } elseif ($Tokens.Count -eq 2 -and $LastWord -eq "") {
            # make sure name matches exactly
            [string]$ApplicationName = $ValidAppNames | Where-Object { $_ -eq $Tokens[1] }
            if ($ApplicationName -ne "") {
              # name is valid, so get version numbers
              [int[]]$Versions = Get-IHIApplicationPackageVersions -ApplicationName $ApplicationName
              $Versions
            }
          } elseif ($Tokens.Count -eq 3 -and $LastWord -ne "") {
            # make sure name matches exactly
            [string]$ApplicationName = $ValidAppNames | Where-Object { $_ -eq $Tokens[1] }
            # name is valid, so get version numbers
            if ($ApplicationName -ne "") {
              [string[]]$Versions = Get-IHIApplicationPackageVersions -ApplicationName $ApplicationName
              # do partial match and return
              $Versions | Where-Object { $_ -match "^$LastWord" }
            }
          } elseif ($Tokens.Count -eq 3 -and $LastWord -eq "") {
            # make sure name matches exactly
            [string]$ApplicationName = $ValidAppNames | Where-Object { $_ -eq $Tokens[1] }
            # name is valid, assume version is valid (will be checked during deploy)
            $Version = $Tokens[2]
            # so get names of deploy server nicknames
            if ($ApplicationName -ne "") {
              $ReleaseFolderApplicationFolder = Get-IHIAppVersionReleasePackageFolder -ApplicationName $ApplicationName -Version $Version
              $ReleaseFolderApplicationConfigFile = Join-Path -Path $ReleaseFolderApplicationFolder -ChildPath (Get-IHIApplicationConfigFileName -ApplicationName $ApplicationName)
              [xml]$ConfigContent = [xml](Get-Content -Path $ReleaseFolderApplicationConfigFile)
              [string[]]$ServerNicknames = Get-IHIDeployServersFromXml -ApplicationXml $ConfigContent | Select -ExpandProperty NickName
              $ServerNicknames
            }
          } elseif ($Tokens.Count -eq 4 -and $LastWord -ne "") {
            # make sure name matches exactly
            [string]$ApplicationName = $ValidAppNames | Where-Object { $_ -eq $Tokens[1] }
            # name is valid, assume version is valid (will be checked during deploy)
            $Version = $Tokens[2]
            # so get names of deploy server nicknames
            if ($ApplicationName -ne "") {
              $ReleaseFolderApplicationFolder = Get-IHIAppVersionReleasePackageFolder -ApplicationName $ApplicationName -Version $Version
              $ReleaseFolderApplicationConfigFile = Join-Path -Path $ReleaseFolderApplicationFolder -ChildPath (Get-IHIApplicationConfigFileName -ApplicationName $ApplicationName)
              [xml]$ConfigContent = [xml](Get-Content -Path $ReleaseFolderApplicationConfigFile)
              [string[]]$ServerNicknames = Get-IHIDeployServersFromXml -ApplicationXml $ConfigContent | Select -ExpandProperty NickName
              # do partial match and return
              $ServerNicknames | Where-Object { $_ -match "^$LastWord" }
            }
          } else {
            # return "" so tab expansion stops running after last valid param
            ""
          }
          break
        }
        { "version" -contains $Tokens[0] } {
          # if only one token and space after first token, show full app names list
          # if two tokens and $LastWord is not "", show app names that match 2nd item
          # if two tokens and $LastWord is "", they entered a full second param, a full app name, so ignore
          # more than two, ignore
          if ($Tokens.Count -eq 1 -and $LastWord -eq "") {
            $ValidAppNames
          } elseif ($Tokens.Count -eq 2 -and $LastWord -ne "") {
            $ValidAppNames | Where-Object { $_ -match "^$LastWord" }
          } else {
            # return "" so tab expansion stops running after last valid param
            ""
          }
          break
        }
		{ "deployps" -contains $Tokens[0] } {
		  # As application name is always PowerShell3 show list of version numbers with first token
		  # if two tokens and $LastWord is "",
		  #   show all applicable deploy environments
		  # if two tokens and $LastWord is NOT "",
		  #   show all applicable deploy environments
		  # set ApplicationName to PowerShell since this is always the case here
		  [string]$ApplicationName = "POWERSHELL3"
		  if ($Tokens.Count -eq 1 -and $LastWord -eq "") {
		  	[int[]]$Versions = Get-IHIApplicationPackageVersions -ApplicationName $ApplicationName
            $Versions
		  } elseif ($Tokens.Count -eq 2 -and $LastWord -ne "") {
			[int[]]$Versions = Get-IHIApplicationPackageVersions -ApplicationName $ApplicationName
			# do partial match and return
            $Versions | Where-Object { $_ -match "^$LastWord" }
          } elseif ($Tokens.Count -eq 2 -and $LastWord -eq "") {
		    # ApplicationName is already PowerShell, assuming version is valid (will be checked during deploy)
            $Version = $Tokens[1]
            # so get names of deploy server nicknames
		    $ReleaseFolderApplicationFolder = Get-IHIAppVersionReleasePackageFolder -ApplicationName $ApplicationName -Version $Version
            $ReleaseFolderApplicationConfigFile = Join-Path -Path $ReleaseFolderApplicationFolder -ChildPath (Get-IHIApplicationConfigFileName -ApplicationName $ApplicationName)
            [xml]$ConfigContent = [xml](Get-Content -Path $ReleaseFolderApplicationConfigFile)
            [string[]]$ServerNicknames = Get-IHIDeployServersFromXml -ApplicationXml $ConfigContent | Select -ExpandProperty NickName
            $ServerNicknames
		  } elseif ($Tokens.Count -eq 3 -and $LastWord -ne "") {
		    # ApplicationName is already PowerShell, assuming version is valid (will be checked during deploy)
            $Version = $Tokens[1]
            # so get names of deploy server nicknames matching existing partial string
		    $ReleaseFolderApplicationFolder = Get-IHIAppVersionReleasePackageFolder -ApplicationName $ApplicationName -Version $Version
            $ReleaseFolderApplicationConfigFile = Join-Path -Path $ReleaseFolderApplicationFolder -ChildPath (Get-IHIApplicationConfigFileName -ApplicationName $ApplicationName)
            [xml]$ConfigContent = [xml](Get-Content -Path $ReleaseFolderApplicationConfigFile)
            [string[]]$ServerNicknames = Get-IHIDeployServersFromXml -ApplicationXml $ConfigContent | Select -ExpandProperty NickName
            # do partial match and return
            $ServerNicknames | Where-Object { $_ -match "^$LastWord" }
		  } else {
            # return "" so tab expansion stops running after last valid param
            ""
          }
          break
		}
		{ "releasenotes" -contains $Tokens[0] } {
		  # This is to get the Release Notes created out of the project but to do so
		  # need to check out the build directory then run the svn command from there
		  # So need not only the project to get from SVN but also the last version built
		  # to get notes for, the baseline for changes will always be PROD
		  if ($Tokens.Count -eq 1 -and $LastWord -eq "") {
		    $ValidAppNames
		  } elseif ($Tokens.Count -eq 2 -and $LastWord -ne "") {
            $ValidAppNames | Where-Object { $_ -match "^$LastWord" }
		  } elseif ($Tokens.Count -eq 3 -and $LastWord -eq "") {
            # make sure name matches exactly
            [string]$ApplicationName = $ValidAppNames | Where-Object { $_ -eq $Tokens[1] }
            if ($ApplicationName -ne "") {
              # name is valid, so get version numbers
              [int[]]$Versions = Get-IHIApplicationPackageVersions -ApplicationName $ApplicationName
              $Versions
            }
		  } elseif ($Tokens.Count -eq 3 -and $LastWord -eq "") {
            # make sure name matches exactly
            [string]$ApplicationName = $ValidAppNames | Where-Object { $_ -eq $Tokens[1] }
            if ($ApplicationName -ne "") {
              # name is valid, so get version numbers
              [int[]]$Versions = Get-IHIApplicationPackageVersions -ApplicationName $ApplicationName
              $Versions
            }
		  } elseif ($Tokens.Count -eq 3 -and $LastWord -ne "") {
            # make sure name matches exactly
            [string]$ApplicationName = $ValidAppNames | Where-Object { $_ -eq $Tokens[1] }
            # name is valid, so get version numbers
            if ($ApplicationName -ne "") {
              [string[]]$Versions = Get-IHIApplicationPackageVersions -ApplicationName $ApplicationName
              # do partial match and return
              $Versions | Where-Object { $_ -match "^$LastWord" }
            }
          } else {
		    # return "" so tab expansion stops running after last valid param
			""
		  }
		  break
		}
        { "apphistory" -contains $Tokens[0] } {
          # if only one token and space after first token, show full app names list
          # if two tokens and $LastWord is not "", show app names that match 2nd item
          # if two tokens and $LastWord is "", they entered a full second param, a full app name, so ignore
          # more than two, ignore
          if ($Tokens.Count -eq 1 -and $LastWord -eq "") {
            $ValidAppNames
          } elseif ($Tokens.Count -eq 2 -and $LastWord -ne "") {
            $ValidAppNames | Where-Object { $_ -match "^$LastWord" }
          } elseif ($Tokens.Count -eq 3 -and $LastWord -ne "") {
            # make sure name matches exactly
            [string]$ApplicationName = $ValidAppNames | Where-Object { $_ -eq $Tokens[1] }
            # name is valid, so get version numbers
            if ($ApplicationName -ne "") {
              [string[]]$Versions = Get-IHIApplicationPackageVersions -ApplicationName $ApplicationName
            }
            # so get names of deploy server nicknames matching existing partial string
		    $ReleaseFolderApplicationFolder = Get-IHIAppVersionReleasePackageFolder -ApplicationName $ApplicationName -Version $Versions[0]
            $ReleaseFolderApplicationConfigFile = Join-Path -Path $ReleaseFolderApplicationFolder -ChildPath (Get-IHIApplicationConfigFileName -ApplicationName $ApplicationName)
            [xml]$ConfigContent = [xml](Get-Content -Path $ReleaseFolderApplicationConfigFile)
            [string[]]$ServerNicknames = Get-IHIDeployServersFromXml -ApplicationXml $ConfigContent | Select -ExpandProperty NickName
            # do partial match and return
            $ServerNicknames | Where-Object { $_ -match "^$LastWord" }
          } elseif ($Tokens.Count -eq 3 -and $LastWord -eq "") {
            # make sure name matches exactly
            [string]$ApplicationName = $ValidAppNames | Where-Object { $_ -eq $Tokens[1] }
            # name is valid, so get version numbers
            if ($ApplicationName -ne "") {
              [string[]]$Versions = Get-IHIApplicationPackageVersions -ApplicationName $ApplicationName
            }
            # so get names of deploy server nicknames matching existing partial string
		    $ReleaseFolderApplicationFolder = Get-IHIAppVersionReleasePackageFolder -ApplicationName $ApplicationName -Version $Versions[0]
            $ReleaseFolderApplicationConfigFile = Join-Path -Path $ReleaseFolderApplicationFolder -ChildPath (Get-IHIApplicationConfigFileName -ApplicationName $ApplicationName)
            [xml]$ConfigContent = [xml](Get-Content -Path $ReleaseFolderApplicationConfigFile)
            [string[]]$ServerNicknames = Get-IHIDeployServersFromXml -ApplicationXml $ConfigContent | Select -ExpandProperty NickName
            # do partial match and return
            $ServerNicknames | Where-Object { $_ -match "^$LastWord" }
          } else {
            # return "" so tab expansion stops running after last valid param
            ""
          }
          break
        }
      }
    }
  }
}
#endregion
