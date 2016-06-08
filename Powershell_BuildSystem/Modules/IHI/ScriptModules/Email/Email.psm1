
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


#region Functions: Send-IHIMailMessage

<#
.SYNOPSIS
Sends an SMTP email message
.DESCRIPTION
Sends an SMTP email message.  Can include cc:, bcc:, attachments. Body is HTML 
by default, specify -BodyAsText to send as text. Depending on the value of domain
filter ($Ihi:Network.Email.MailRelay.DomainFilters), email addresses might be 
filtered out.  This prevents relay errors when emails are attempted to be sent 
from internal machines to external addresses.
.PARAMETER To
List of email addresses to send to
.PARAMETER Subject
Subject of email
.PARAMETER Body
Body of email
.PARAMETER From
From address; if not supplied uses server-specific address
.PARAMETER SmtpServer
Server to route email through; if not supplied uses server-specific address
.PARAMETER Attachments
List of paths of files to attach to mail message
.PARAMETER Cc
List of email addresses to CC
.PARAMETER Bcc
List of email addresses to BCC
.PARAMETER BodyAsText
Formats body as text, not HTML (the default)
.PARAMETER HighPriority
Set message as high priority (default is normal)
.EXAMPLE
Send-IHIMailMessage -To ksweeney@ihi.org -From admin@ihi.org -Subject "hey now" -Body "some text"
Sends email to ksweeney@ihi.org from admin@ihi.org with subject and body
.EXAMPLE
Send-IHIMailMessage -To ksweeney@ihi.org -Subject "hey now" -Body "some text"
Sends email but uses default from address of ps_<machine name>@ihi.org
.EXAMPLE
Send-IHIMailMessage -To ksweeney@ihi.org -Subject "hey now" -Body "some text" -HighPriority
Sends email with high priority
.EXAMPLE
Send-IHIMailMessage -To ("ksweeney@ihi.org","phamnett@ihi.org") -Subject "hey now" -Body "some text"
Sends email to multiple people.
.EXAMPLE
Send-IHIMailMessage -To ksweeney@ihi.org -Cc phamnett@ihi.org -Subject "hey now" -Body "some text"
Sends email to with carbon copy.
.EXAMPLE
Send-IHIMailMessage -To ("ksweeney@ihi.org","someaddress@yahoo.com") -Subject "hey now" -Body "some text"
Sends email but it MIGHT filter out the yahoo.com email, depending on the value of domain filter
for this server.  Domain filter ($Ihi:Network.Email.MailRelay.DomainFilters) is set to @ihi.org
on internal servers to prevent outside emails addresses from failing during routing
#>
function Send-IHIMailMessage {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$To,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Subject,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Body,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$From = $Ihi:Network.Email.DefaultFromAddress,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$SmtpServer = $Ihi:Network.Email.MailRelay.RelayServer,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$Attachments,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$Cc,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string[]]$Bcc,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$BodyAsText,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [switch]$HighPriority
  )
  #endregion
  process {
    #region Make sure Attachments paths are valid
    if ($Attachments -ne $null -and $Attachments.Count -gt 0) {
      foreach ($Attachment in $Attachments) {
        if ($false -eq (Test-Path -Path $Attachment)) {
          Write-Error -Message "$($MyInvocation.MyCommand.Name):: attachment not found: $Attachment"
          return
        }
      }
    }
    #endregion

    #region Report original information - regardless of whether or not sending
    # rather than use PSBoundParameters, manually output for better formatting
    Write-Host "$($MyInvocation.MyCommand.Name) called with:"
    Add-IHILogIndentLevel
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "From",$From)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Original To",("$To"))
    if ($Cc -ne $null -and $Cc.Count -gt 0) {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Original Cc",("$Cc"))
    }
    if ($Bcc -ne $null -and $Bcc.Count -gt 0) {
      Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Original Bcc",("$Bcc"))
    }
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Subject",$Subject)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Body","<$($Body.Length) characters>")
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "SmtpServer",$SmtpServer)
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "HTML",(!$BodyAsText))
    Write-Host $("{0,-$DefaultCol1Width} {1}" -f "HighPriority",$HighPriority)
    # if multiple attachments, output on separate lines else
    # just write single entry
    if ($Attachments -ne $null -and $Attachments.Count -gt 0) {
      if ($Attachments.Count -eq 1) {
        Write-Host $("{0,-$DefaultCol1Width} {1}" -f "Attachments",$Attachments[0])
      } else {
        Write-Host "Attachments:"
        Add-IHILogIndentLevel
        $Attachments | ForEach-Object {
          Write-Host "$_"
        }
        Remove-IHILogIndentLevel
      }
    }
    #endregion

    #region Copy To, Cc and Bcc to new variables
    # Because we are potentially modifying the contents of To, Cc and Bcc in the domain filtering
    # we need to copy the contents to new variables and only use those variables going forward
    [string[]]$ToAddresses = $To
    [string[]]$CcAddresses = $Cc
    [string[]]$BccAddresses = $Bcc
    #endregion

    #region Check if email enabled currently on this server
    if ($Ihi:Network.Email.MailRelay.Enabled -eq $false) {
      Write-Host "Email disabled on this machine - email NOT sent"
      return
    }
    #endregion

    #region If filtering enabled, remove emails that don't match
    if ($Ihi:Network.Email.MailRelay.DomainFilters -ne $null -and
      $Ihi:Network.Email.MailRelay.DomainFilters -ne "") {
      Write-Host "Running domain filters on email addresses"
      Add-IHILogIndentLevel
      # Domain filters could be an array of mail domains so loop through and combine, separated by |
      [string]$Filter = ""
      for ($i = 0; $i -lt $Ihi:Network.Email.MailRelay.DomainFilters.Count; $i++) {
        $Filter += $Ihi:Network.Email.MailRelay.DomainFilters[$i]
        if ($i -lt ($Ihi:Network.Email.MailRelay.DomainFilters.Count - 1)) { $Filter += "|" }
      }
      #region Filter ToAddresses
      # To is required so no need to check if any
      $TempIn = $null
      $TempOut = $null
      $ToAddresses | ForEach-Object {
        if ($_ -match $Filter) { $TempIn += (,$_) }
        else { $TempOut += (,$_) }
      }
      # if $TempOut contains items, report them
      if ($TempOut -ne $null) {
        Write-Host "Remaining To addresses: $("$TempIn")"
        Write-Host "Filtered out these To addresses: $("$TempOut")"
      }
      # set emails to send - if any, could be null
      $ToAddresses = $TempIn
      # To is required so should be at least one address, if none remaining, exit
      if ($ToAddresses -eq $null) {
        Write-Host "No To email addresses remain after domain filtering - email NOT sent"
        Remove-IHILogIndentLevel
        Remove-IHILogIndentLevel
        return
      }
      #endregion

      #region Filter CcAddresses
      if ($CcAddresses -ne $null -and $CcAddresses -ne "") {
        # loop through Cc email addresses
        $TempIn = $null
        $TempOut = $null
        $CcAddresses | ForEach-Object {
          if ($_ -match $Filter) { $TempIn += (,$_) }
          else { $TempOut += (,$_) }
        }
        # if $TempOut contains items, report them
        if ($TempOut -ne $null) {
          Write-Host "Remaining Cc addresses: $("$TempIn")"
          Write-Host "Filtered out these Cc addresses: $("$TempOut")"
        }
        # set emails to send - if any, could be null
        $CcAddresses = $TempIn
      }
      #endregion

      #region Filter BccAddresses
      if ($BccAddresses -ne $null -and $BccAddresses -ne "") {
        # loop through Bcc email addresses
        $TempIn = $null
        $TempOut = $null
        $BccAddresses | ForEach-Object {
          if ($_ -match $Filter) { $TempIn += (,$_) }
          else { $TempOut += (,$_) }
        }
        # if $TempOut contains items, report them
        if ($TempOut -ne $null) {
          Write-Host "Remaining Bcc addresses: $("$TempIn")"
          Write-Host "Filtered out these Bcc addresses: $("$TempOut")"
        }
        # set emails to send - if any, could be null
        $BccAddresses = $TempIn
      }
      #endregion
      Remove-IHILogIndentLevel
    }
    # check if any addresses remain after filtering, if not exit
    #endregion

    #region Create email
    # create new email message and populate basic values
    $Msg = New-Object System.Net.Mail.MailMessage
    $Msg.From = New-Object System.Net.Mail.MailAddress ($From,$From);
    # add To addresses
    $ToAddresses | ForEach-Object { $Msg.To.Add($_) }
    # add Cc and Bcc
    if ($CcAddresses -ne $null -and $CcAddresses.Count -gt 0) {
      $CcAddresses | ForEach-Object { $Msg.Cc.Add($_) }
    }
    if ($BccAddresses -ne $null -and $BccAddresses.Count -gt 0) {
      $BccAddresses | ForEach-Object { $Msg.Bcc.Add($_) }
    }
    $Msg.Subject = $Subject
    $Msg.Body = $Body
    # we assume body is always HTML, need to specify BodyAsText to get as text
    $Msg.IsBodyHtml = !$BodyAsText
    # set priority to High if passed, else normal
    if ($HighPriority) { $Msg.Priority = $Msg.Priority = [System.Net.Mail.MailPriority]::High }
    #region Create and add Attachments
    $SmtpAttachments = $null
    if ($Attachments -ne $null -and $Attachments.Count -gt 0) {
      # create SMTP attachment objects separately so can be disposed
      $SmtpAttachments = $Attachments | ForEach-Object { New-Object Net.Mail.Attachment ($_) }
      # now added each SMTP attachment
      $SmtpAttachments | ForEach-Object { $Msg.Attachments.Add($_) }
    }
    #endregion
    #endregion

    #region Send email
    # create email and set SMTP relay server
    $SmtpClient = New-Object System.Net.Mail.SmtpClient
    $SmtpClient.Host = $SmtpServer
    try {
      Write-Host "Sending email"
      $SmtpClient.Send($Msg)
      # .Dispose() to release file locks
      if ($null -ne $SmtpAttachments) { $SmtpAttachments | ForEach-Object { $_.Dispose() } }
      $Msg.Dispose()
    }
    catch {
      Write-Error -Message "$($MyInvocation.MyCommand.Name):: error occurred sending email: $("$_")"
      return
    }
    finally {
      Remove-IHILogIndentLevel
    }
    #endregion
  }
}
Export-ModuleMember -Function Send-IHIMailMessage
#endregion
