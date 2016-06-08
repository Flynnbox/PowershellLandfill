
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


#region Functions: Send-IHIBuildEmail

<#
.SYNOPSIS
Sends an build email - error or success
.DESCRIPTION
Sends an build email - error or success.  If an error occurred, ErrorOccurred
should be passed and ErrorMessage should be specified.
.PARAMETER Time
Time the build processed was started
.PARAMETER To
User(s) to send email to
.PARAMETER ApplicationName
Name of application
.PARAMETER Version
Version of application
.PARAMETER BuildRunAsUserName
User the build process is running as locally
.PARAMETER BuildLaunchUserName
User that launched the process, may be different from BeployRunAsUserName
.PARAMETER LogFiles
Path to log file(s) generated by build
.PARAMETER ErrorOccurred
Specified if an error occurred during build
.PARAMETER ErrorMessage
Error message associated with the error
.EXAMPLE
Send-IHIBuildEmail (Get-Date) ksweeney@ihi.org Extranet 9876
Sends builds email with included information
#>
function Send-IHIBuildEmail {
  #region Function parameters
  [CmdletBinding()]
  param(
    # Depending on when the error is detected some or almost all of values may not be known
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [datetime]$Time,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$To,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$ApplicationName,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$Version,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$BuildRunAsUserName,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$BuildLaunchUserName,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$LogFiles,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$ErrorOccurred,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$ErrorMessage
  )
  #endregion
  process {
    #region Set UserInfo
    # for now, only using runas user info
    [string]$UserInfo = $null
    if ($BuildRunAsUserName -eq $BuildLaunchUserName) {
      $UserInfo = $BuildRunAsUserName
    } else {
      $UserInfo = $BuildRunAsUserName + " - " + $BuildLaunchUserName
    }
    #endregion

    #region Set subject
    [string]$Subject = ""
    if ($ErrorOccurred) {
      # if application and version name not known yet, major issue with build, probably bad xml
      # in this case, just report xml path
      if ($ApplicationName -eq "" -and $Version -eq "") {
        $Subject = "major build error"
      } else {
        $Subject = "$ApplicationName $Version *build error* by $UserInfo"
      }
    } else {
      $Subject = "$ApplicationName $Version built by $UserInfo"
    }
    #endregion

    #region Set body first line
    [string]$BodyFirstLine = ""
    if ($ErrorOccurred) {
      $BodyFirstLine = "<TR><TD colspan=2 class='shaded'><h1>$ApplicationName $Version <font color='red'>*BUILD ERROR*</font> on $($Time.DayOfWeek) $($Time.ToString("G"))</h1></TD></TR>`n"
    } else {
      $BodyFirstLine = "<TR><TD colspan=2 class='shaded'><h1>$ApplicationName $Version built successfully on $($Time.DayOfWeek) $($Time.ToString("G"))</h1></TD></TR>`n"
    }
    #endregion

    #region Compose Body
    [System.Text.StringBuilder]$Body = New-Object System.Text.StringBuilder
    #region Add basic header and body / first line
    $Body.Append("<HTML>`n") > $null
    $Body.Append("<HEAD>`n") > $null
    $Body.Append((Get-IHIHtmlEmailCssStyle1)) > $null
    $Body.Append("</HEAD>`n") > $null
    $Body.Append("<BODY>`n") > $null
    $Body.Append("<TABLE cellpadding='0' cellspacing='0'>`n") > $null
    $Body.Append($BodyFirstLine) > $null
    #endregion

    #region Add basic body info if it exists
    if ($ApplicationName -ne "") {
      $Body.Append("<TR>`n") > $null
      $Body.Append("  <TD class='label'>" + "Application:" + "</TD>`n") > $null
      $Body.Append("  <TD>" + $ApplicationName + "</TD>`n") > $null
      $Body.Append("</TR>`n") > $null
    }
    if ($Version -ne "") {
      $Body.Append("<TR>`n") > $null
      $Body.Append("  <TD class='label'>" + "Version:" + "</TD>`n") > $null
      $Body.Append("  <TD>" + $Version + "</TD>`n") > $null
      $Body.Append("</TR>`n") > $null
    }
    if ($UserInfo -ne "") {
      $Body.Append("<TR>`n") > $null
      $Body.Append("  <TD class='label'>" + "User:" + "</TD>`n") > $null
      $Body.Append("  <TD>" + $UserInfo + "</TD>`n") > $null
      $Body.Append("</TR>`n") > $null
    }
    #endregion

    #region Add error info, if this is an error email
    # one thing we know about the error messages is that there tends to be a :: separator
    # between the main message and lower, repeated errors.  
    # also, for errors in scriptblocks, the script is surrounded by --> and <-- 
    # let's use this to put a new line <BR/> in the message for readability
    # also look for carriage return characters and replace with new line
    if ($ErrorOccurred) {
      $Body.Append("<TR>`n") > $null
      $Body.Append("  <TD class='label' valign='top'>" + "Error:" + "</TD>`n") > $null
      $ErrMsg = $ErrorMessage.Replace(" :: ","<BR/><BR/>").Replace("-->","<BR/><BR/>").Replace("<--","<BR/><BR/>").Replace("`r","<BR/>")
      $Body.Append("  <TD>" + $ErrMsg + "</TD>`n") > $null
      $Body.Append("</TR>`n") > $null
    }
    #endregion

    #region Wrap up xml
    $Body.Append("</BODY>`n") > $null
    $Body.Append("</HTML>`n") > $null
    #endregion
    #endregion

    #region Send email
    # if To is null, use $Ihi:BuildDeploy.ErrorNotificationEmails
    if ($To -eq $null) {
      $To = $Ihi:BuildDeploy.ErrorNotificationEmails
    }
    # add basic params, always send emails from specific account
    [hashtable]$Params = @{ To = $To; Subject = $Subject; Body = $Body.ToString(); Attachments = $LogFiles; From = "BuildProcess@ihi.org" }
    # if error occurred, CC build managers
    if ($ErrorOccurred) {
      $Params.Cc = $Ihi:BuildDeploy.ErrorNotificationEmails
    }
    Send-IHIMailMessage @Params
    #endregion
  }
}
Export-ModuleMember -Function Send-IHIBuildEmail
#endregion