
#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
    # when writing name/value pairs, width of first column
    [int]$script:DefaultCol1Width = 20
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Backup-IHIItemSimple

<#
.SYNOPSIS
Makes a simple backup of a file or folder - copy with a datetime stamp
.DESCRIPTION
Makes a simple backup of a file or folder - copy with a datetime stamp. The
backup copy is put in the same folder as the source item.  Optionally, you can
specify the -BackupFolder param which causes the backup item to be put in a 
folder named _Backup in the same folder as the source item.
.PARAMETER Path
Path to file or folder to back up
.PARAMETER BackupFolder
Specify to store backup copy in a _Backup folder located in relative location.
.EXAMPLE
Backup-IHIItemSimple -Path c:\temp\file1.txt
Copies file1.txt into new file c:\temp\file1.txt.<datetimestamp> 
.EXAMPLE
Backup-IHIItemSimple -Path c:\temp\file1.txt -BackupFolder
Copies file1.txt into new file c:\temp\_BackupFolder\file1.txt.<datetimestamp> 
#>
function Backup-IHIItemSimple {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$BackupFolder
  )
  #endregion
  process {
    #region Parameter validation
    #region Confirm source path exists
    if ($false -eq (Test-Path -Path $Path)) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: source folder path is null or bad: $Path"
      return
    }
    #endregion
    #endregion

    #region Report information before processing files
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Path",$Path)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "BackupFolder",$BackupFolder)
    Remove-IHILogIndentLevel
    #endregion

    #region Set various destination path
    [string]$ParentPath = Split-Path -Path $Path -Parent
    [string]$ItemName = Split-Path -Path $Path -Leaf
    [string]$BackupItemName = $ItemName + ("_{0:yyyyMMdd_HHmmss}" -f (Get-Date))
    [string]$DestinationPath = $null
    if ($BackupFolder -eq $true) {
      $DestinationPath = Join-Path -Path $ParentPath -ChildPath "_BackupFolder"
      $DestinationPath = Join-Path -Path $DestinationPath -ChildPath $BackupItemName
    } else {
      $DestinationPath = Join-Path -Path $ParentPath -ChildPath $BackupItemName
    }
    #endregion

    #region Check if _BackupFolder needs to be created
    if ($BackupFolder -eq $true) {
      $BackupFolderFullPath = Join-Path -Path $ParentPath -ChildPath "_BackupFolder"
      if ($false -eq (Test-Path -Path $BackupFolderFullPath)) {
        $Results = New-Item -Path $BackupFolderFullPath -ItemType Directory 2>&1
        if ($? -eq $false) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred creating backup folder $BackupFolderFullPath :: $("$Results")"
          return
        }
      }
    }
    #endregion

    #region Copy item
    # copy item to backup location; specify -Recurse in case it's a folder to get subfolder contents
    $Results = Copy-Item -Path $Path -Destination $DestinationPath -Recurse 2>&1
    if ($? -eq $false) {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred copying backup from $Path to $DestinationPath :: $("$Results")"
      return
    }
    Write-Host "Backup complete"
    #endregion
  }
}
Export-ModuleMember -Function Backup-IHIItemSimple

#endregion
