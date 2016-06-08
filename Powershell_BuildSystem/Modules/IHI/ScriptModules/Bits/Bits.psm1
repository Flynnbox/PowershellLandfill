
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


#region Functions: Confirm-IHIBitsService

<#
.SYNOPSIS
Confirms BITS is running, if not starts and returns success bool
.DESCRIPTION
Confirms BITS is running, if not starts and returns bool if successful or not
in starting service
.PARAMETER Msg
Reference to string where return messages are stored if success or failure
.EXAMPLE
Confirm-IHIBitsService -Msg ([ref]$ResultsMsg)
Confirms BITS is running, puts messages in $ResultsMsg and returns bool
#>
function Confirm-IHIBitsService {
  #region Function parameters
  [CmdletBinding()]
  param(
    # Pass in a reference to a string object for Messages
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [ref]$Msg
  )
  #endregion
  process {
    # Clear any previous messages
    $Msg.value = $null

    # Check BITS Service
    # If the service isn't running start it
    # Get the BITS Service Object
    $BitsService = Get-Service -Name BITS -ErrorAction SilentlyContinue
    if ($BitsService -ne $null) {
      # Found the Service
      if ($BitsService.Status -ne 'Running')
      {
        # Try to start the service
        $Msg.value += Add-IHITimeStampPrefix "Attempting to start the BITS Service"
        try
        {
          $BitsService.Start()
          $BitsService.WaitForStatus('Running',(New-TimeSpan -Seconds 5))
          $Msg.value += Add-IHITimeStampPrefix "Started the BITS Service"
        }
        catch [System.Exception]
        {
          # The .WaitForStatus throws an error if the timeout period is exceeded
          # 	Exception calling "WaitForStatus" with "2" argument(s): "Time out has expired and the operation has not been completed."
          $Msg.value += Add-IHITimeStampPrefix ("Failed to start the BITS Service")
          $Msg.value += Add-IHITimeStampPrefix ("Exception: " + $_.Exception.GetType().FullName)
          $Msg.value += Add-IHITimeStampPrefix ($_.Exception.Message)
          return $false
        }
      }
      else
      {
        $Msg.value += Add-IHITimeStampPrefix "BITS Service is already running"
      }
    } else {
      # Service Not Found
      $Msg.value += Add-IHITimeStampPrefix "Failed to find the BITS Service"
      return $false
    }
    # SUCCESS
    return $true
  }
}
Export-ModuleMember -Function Confirm-IHIBitsService
#endregion


#region Functions: Get-IHIOptimalSizeFromBytes

<#
.SYNOPSIS
Converts bytes value into closest larger format
.DESCRIPTION
Converts bytes value into closest larger format.  For example converts
100000000 into 95.4MB; handles largers sizes as well: KB, MB, GB, TB, PB, EB, ZB, YB
.PARAMETER SizeInBytes
Size in bytes
.PARAMETER Precision
Precision
.EXAMPLE
Get-IHIOptimalSizeFromBytes -SizeInBytes 100000000
Returns: 95.4MB
Disables SharePoint feature
#>
function Get-IHIOptimalSizeFromBytes {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [Alias("s")]
    [int64]$SizeInBytes,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [Alias("p")]
    [int]$Precision = 1
  )
  #endregion  
  # Convert to the optimal display size
  foreach ($i in ("bytes","KB","MB","GB","TB","PB","EB","ZB","YB")) {
    if ($SizeInBytes -lt 1KB) { break; }
    [double]$SizeInBytes /= 1KB;
  }
  # Format results
  $SizeInBytes.ToString("F0" + $Precision) + $i
}
Export-ModuleMember -Function Get-IHIOptimalSizeFromBytes
#endregion


#region Functions: Get-IHITransferRateInBits

<#
.SYNOPSIS
Returns transfer rate of file in particular format from bits
.DESCRIPTION
Returns the rate of a file transfer in a format you can specify, default
format of bytes
.PARAMETER SizeInBytes
Size of file in bytes
.PARAMETER StartDate
Start datetime of copy
.PARAMETER EndDate
End datetime of copy (use current time if not specifed)
.PARAMETER Unit
Unit of file format (bytes by default)
.PARAMETER Precision
Precision
.EXAMPLE
Get-IHITransferRateInBits -SizeInBytes 1000000000 -StartDate <some date>
#>
function Get-IHITransferRateInBits {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [Alias("s")]
    [int64]$SizeInBytes,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [datetime]$StartDate,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [datetime]$EndDate = (Get-Date),
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [Alias("u")]
    [string]$Unit = "bits",
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [Alias("p")]
    [int]$Precision = 1
  )
  #endregion
  process {
    # Get the duration in a time object
    $DurationTime = $EndDate - $StartDate;
    # Get the Bytes Per Second
    [double]$BitsPerSecond = ($SizeInBytes / $DurationTime.TotalSeconds) * 8
    # Convert to proper unit
    switch ($Unit)
    {
      "Kb" { ($BitsPerSecond / 1KB).ToString("F0" + $Precision) + "Kb/s"; break; }
      "Mb" { ($BitsPerSecond / 1MB).ToString("F0" + $Precision) + "Mb/s"; break; }
      "Gb" { ($BitsPerSecond / 1GB).ToString("F0" + $Precision) + "Gb/s"; break; }
      "Tb" { ($BitsPerSecond / 1TB).ToString("F0" + $Precision) + "Tb/s"; break; }
      default { ($BitsPerSecond).ToString("F0" + $Precision) + "bits/s"; break; }
    }
  }
}
Export-ModuleMember -Function Get-IHITransferRateInBits
#endregion


#region Functions: Get-IHITransferRateInBytes

<#
.SYNOPSIS
Returns transfer rate of file in particular format from bytes
.DESCRIPTION
Returns the rate of a file transfer in a format you can specify, default
format of bytes
.PARAMETER SizeInBytes
Size of file in bytes
.PARAMETER StartDate
Start datetime of copy
.PARAMETER EndDate
End datetime of copy (use current time if not specifed)
.PARAMETER Unit
Unit of file format (bytes by default)
.PARAMETER Precision
Precision
.EXAMPLE
Get-IHITransferRateInBytes -SizeInBytes 1000000000 -StartDate <some date>
#>
function Get-IHITransferRateInBytes {
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [Alias("s")]
    [int64]$SizeInBytes,
    [Parameter(Mandatory = $true,ValueFromPipeline = $false)]
    [datetime]$StartDate,
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [datetime]$EndDate = (Get-Date),
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [Alias("u")]
    [string]$Unit = "bytes",
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [Alias("p")]
    [int]$Precision = 1
  )
  #endregion
  process {
    # Get the duration in a time object
    $DurationTime = $EndDate - $StartDate;
    # Get the Bytes Per Second
    [double]$BytesPerSecond = $SizeInBytes / $DurationTime.TotalSeconds
    # Convert to proper unit
    switch ($Unit)
    {
      "KB" { ($BytesPerSecond / 1KB).ToString("F0" + $Precision) + "KB/s"; break; }
      "MB" { ($BytesPerSecond / 1MB).ToString("F0" + $Precision) + "MB/s"; break; }
      "GB" { ($BytesPerSecond / 1GB).ToString("F0" + $Precision) + "GB/s"; break; }
      "TB" { ($BytesPerSecond / 1TB).ToString("F0" + $Precision) + "TB/s"; break; }
      default { ($BytesPerSecond).ToString("F0" + $Precision) + "bytes/s"; break; }
    }
    # Just for reference
    # $mbyte_m = (($Job.BytesTotal/1MB)/$DurationTime.TotalMinutes).ToString("F01")+"MB/m";
  }
}
Export-ModuleMember -Function Get-IHITransferRateInBytes
#endregion


#region Functions: Start-IHIFileTransfer

<#
.SYNOPSIS
Transfer file/s between file or web servers using BITS (Background Intelligent Transfer Service)
.DESCRIPTION
This script transfers a file between a file or web server to another file location using BITS.
Parameters can specify the Source Server, the Destination Server and the Credentials for the connection.
By the usage of wildcard for the Source Server location multiple files can be transferred.
.PARAMETER SourcePath
Source file path
.PARAMETER DestinationPath
Destination
.PARAMETER Credentials
Credentials
.EXAMPLE
Start-IHIFileTransfer -s "\\serverS\share\file.ext" -d "\\serverD\share" -c "domain\user"
Transfers the file "file.ext" from source server "\\serverS\share\" to destination server "\\serverD\share"
.EXAMPLE
Start-IHIFileTransfer -s "\\serverS\share\*.*" -d "\\serverD\share"
Transfers multiple files (*.*) from source server "\\serverS\share\" to destination server "\\serverD\share"
.EXAMPLE
Start-IHIFileTransfer -s "\\serverS\share\*.iso" -d "\\serverD\share"
Transfers multipe .iso files from source server "\\serverS\share\" to destination server "\\serverD\share"
.EXAMPLE
Start-IHIFileTransfer -s "http://webserverS/file.ext" -d "\\serverD\share" -c "domain\user"
Transfers the file "file.ext" from source web server "http://webserverS/" to destination server "\\serverD\share"
.EXAMPLE
Start-IHIFileTransfer -s "http://webserverS/file.ext" -d "\\serverD\share" -c "domain1\user1"
Transfers the file "file.ext" from source web server "http://webserverS/" to destination server "\\serverD\share" using the credentials domain1\user1
.INPUTS
SourcePath - Mandatory Parameter
DestinationPath
Credentials
.OUTPUTS
1: "Failed to start BITS service"
2: "Source path $SourcePath does not exist"
3: "Destination is just a path and no filename"
4: "Destination path $parentPath does not exist"
.NOTES
History
1.0.0	20110401 Mark Rovendro	Created
1.0.1	20110501 Mark Rovendro	Major updates
1.0.2	20110523 Mark Rovendro	Updated usage
1.0.3	20110628 Mark Rovendro	Changed main loop to check for state Transferred, various other changes
1.0.4	20110830 Mark Rovendro	Added check/start of BITS Service, changed file parameter checks
.LINK
http://msdn.microsoft.com/en-us/library/aa363160(VS.85).aspx
http://msdn.microsoft.com/en-us/library/aa362783(v=VS.85).aspx
http://msdn.microsoft.com/en-us/library/ee663885(v=VS.85).aspx
http://gallery.technet.microsoft.com/ScriptCenter/en-us/f4349d9d-637c-4989-bb24-d4b4a3a039c6
#>
function Start-IHIFileTransfer {
  #region Function parameters
  [CmdletBinding()]
  param
  (
    <#
	HelpMessage=
@'
Enter a valid download source:
   Eg: 
       \\serverS\share\file.ext 
       or 
       http://serverS.com/file.ext
       or
       Cancel and re-run the script with the correct parameters
                   
   Full usage:
       Start-IHITransferFiles.ps1 -s "path" -d "path" -c "credentials" 
   Full example: - Download single file from a file server
       Start-IHITransferFile.ps1 -s "\\serverS\share\file.ext" -d "\\serverD\share" -c "domain\user"
   Full example: - Download multiple files from a file server, using wildcard E.g. *.* or *.iso 
       Start-IHITransferFile.ps1 -s "\\serverS\share\*.*" -d "\\serverD\share"
'@
#>
    [Parameter(Mandatory = $true)]
    [Alias("s")]
    $SourcePath,
    [Parameter(Mandatory = $true)]
    [Alias("d")]
    $DestinationPath,
    [Alias("c")]
    $Credentials = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  )
  #endregion
  process {

    $ScriptPath = $MyInvocation.MyCommand.Definition # Start with the Full Path and Name
    $ScriptName = Split-Path $ScriptPath -Leaf # Extract the Script Name
    $ScriptPath = Split-Path $ScriptPath -Parent # Extract the Script Path
    $jobName = "Start-FileTransfer" # Used to create BITS Job

    # We need a unique name to be thread safe
    # Not sure this is exactly necessary since we get a unique JobID and we can have multiple 
    # job displayed with the same name. As long as we know what the JobID is we can then get 
    # back to the original
    $rand = New-Object System.Random
    $jobName += $rand.next()

    Add-IHITimeStampPrefix "$ScriptName"
    Add-IHITimeStampPrefix "Src: $SourcePath"
    Add-IHITimeStampPrefix "Dst: $DestinationPath"

    # Verify BITS Service is Running
    $Msg = $null;
    if (!(Confirm-IHIBitsService -Msg ([ref]$Msg)))
    {
      # Parameter contains error messages
      $Msg
      return 1
    }

    # Display messages about the status of the BITS service
    $Msg

    # Test Parameters
    if ((Test-Path -Path $SourcePath -PathType Container) -eq $true)
    {
      Add-IHITimeStampPrefix "[2] Source is a folder, please provide the full path including source filename"
      return 2
    }

    if (!(Test-Path -Path $SourcePath -PathType Leaf))
    {
      Add-IHITimeStampPrefix "[2] Source does not exist"
      return 2
    }

    # First check if destination a container
    if ((Test-Path -Path $DestinationPath -PathType Container) -eq $true)
    {
      Add-IHITimeStampPrefix "[3] Destination is a folder, please provide the full path including destination filename"
      return 3
    }

    # Destination file may or may not exist. We only want to verify that the destination folder
    # exists. We just verified with the above test that we know the Destination is not a valid folder,
    # so we can assume we have the correct format and test the parentPath to see if it exists
    $parentPath = Split-Path $DestinationPath -Parent
    if (!(Test-Path -Path $parentPath))
    {
      Add-IHITimeStampPrefix "[4] Destination folder [$parentPath] does not exist"
      return 4
    }

    # Transfer
    Start-IHIBitsTransferFile

    # Completed Successfully
    return 0
  }
}
Export-ModuleMember -Function Start-IHIFileTransfer
#endregion


#region Functions: Start-IHIBitsTransferFile
function Start-IHIBitsTransferFile
{
  try
  {
    Import-Module BitsTransfer

    #Uncomment -Credential below if server requires alternate credentials
    # This waits 60 seconds between retries, and tries a maximum of 60 times before setting the job to ERROR
    $Job = Start-BitsTransfer -DisplayName $jobName -Source $SourcePath `
       -Destination $DestinationPath -Asynchronous `
       -RetryInterval 60 -RetryTimeout (60 * 60) # -Credential $Credentials -Authentication Passport

    #JobId                   : 873c4db1-4b60-4a49-bd62-0631aacd4099
    #DisplayName             : MyTransfer
    #Description             : This is a file transfer that uses the Background Intelligent Transfer Service (BITS).
    #TransferType            : Download
    #JobState                : Transferring
    #OwnerAccount            : IHI\mrovendro
    #Priority                : Foreground
    #RetryInterval           : 600
    #RetryTimeout            : 1209600
    #TransientErrorCount     : 0
    #ProxyUsage              : SystemDefault
    #ErrorContext            : None
    #ErrorCondition          : NoError
    #InternalErrorCode       : 0
    #ErrorDescription        :
    #ErrorContextDescription :
    #BytesTotal              : 39216640
    #BytesTransferred        : 3145728
    #FilesTotal              : 1
    #FilesTransferred        : 0
    #CreationTime            : 5/9/2011 3:22:54 PM
    #ModificationTime        : 5/9/2011 3:23:02 PM
    #TransferCompletionTime  : 1/1/0001 12:00:00 AM
    #FileList                : {C:\backups\_UTILS.BAK}
    #ProxyList               :
    #ProxyBypassList         :

    # Job
    Write-Host (Add-IHITimeStampPrefix ("JobName: $jobName"))
    Add-IHITimeStampPrefix ("BytesTotal: " + (Get-IHIOptimalSizeBytes $Job.BytesTotal));

    # Monitor Status
    $previousSleep = 0;
    do {
      # Main variables
      $mbit_s = Get-IHITransferRateBits -SizeInBytes $Job.BytesTransferred -StartDate $Job.CreationTime -Unit "Mb";
      $transferRate = [float]($mbit_s -replace "[Mb/s]",""); # remove the Mb/s
      $transferPercent = (($Job.BytesTransferred / $Job.BytesTotal) * 100).ToString("F01") + "%";
      $remainingBytes = $Job.BytesTotal - $Job.BytesTransferred;

      # Sleep Duration
      # 2011.06.28 Mark Rovendro - Added $remainingBytes check
      if ([int]$transferRate -eq 0 -or $remainingBytes -eq 0)
      {
        # Transfer has not started or we have fully transferred and the JobState hasn't updated
        $remainingSeconds = -1;
        $sleepSeconds = 10;
      }
      else
      {
        # Convert bytes to megabytes to megabits divide by transfer rate
        $remainingSeconds = [int]((($remainingBytes / 1MB) * 8) / $transferRate);
        #region Sleep Seconds
        # Basically we want to compute the next time to check on the transfer such that
        # we minimize checking too frequently and writing excessive information to the output
        # which is most likely logged. Long term we probably will add a command line switch 
        # to either for a check interval, or allow the system to compute the optimal check value.
        # For short transfers they always tend to start off faster than they end
        # For longer transfers they seem to complete a bit quicker
        # Example of a long transfer:
        #	2011-05-13T04:05:32 Source: \\daa10197sql005.ihiqhc.corp\backup\PROD_IHIDB\PROD_IHIDB_20110513001503160_D.dff
        #	2011-05-13T04:05:32 Destination: D:\backups\bitstransfer\PROD_IHIDB.dff
        #	2011-05-13T04:05:32 JobName: Start-FileTransfer1055483755
        #	2011-05-13T04:05:32 BytesTotal: 2.3GB
        #	2011-05-13T04:05:32 Connecting...
        #	2011-05-13T04:05:42 0.3% 4.7Mb/s Remaining:3967s Sleeping:3977s
        #	2011-05-13T05:11:59 Final JobState: Transferred
        #	2011-05-13T05:11:59 Completed at 05/13/2011 05:02:28
        #	2011-05-13T05:11:59 Duration: 00:56:56.7120000 TotalMinutes:56.9
        #	2011-05-13T05:11:59 Transfer Rate: 5.5Mb/s 0.7MB/s
        # We see that we completed at 05:02 and checked at 05:11 - 9 minutes later. In this particular
        # case we see that the final transfer rate was higher at the end then we started with. It would be
        # better to say that LAN transfers start higher and that WAN transfers may end higher.
        # So the goal is to just try and not waste those 9 minute if possible.
        # All transfers under 5 minutes were fine adding 10 seconds.
        #endregion

        # Rate>50Mb/s we are on a pretty quick network = Remaining Seconds
        # Rate<12Mb/s we are transferring over a WAN = Percentage of Remaining Seconds depending on 
        Write-Verbose "TransferRate: $transferRate"
        switch ($transferRate)
        {
          # Slower Network
          { $_ -le 10 } {
            Write-Verbose "Slow Network - calculating Sleep"
            switch ($remainingSeconds)
            {
              { $_ -le (60 * 1) } { $sleepSeconds = $remainingSeconds; break; }
              { $_ -le (60 * 5) } { $sleepSeconds = [int]($remainingSeconds * .7); break; }
              default { $sleepSeconds = [int]($remainingSeconds * .6); break; }
            } #$remainingSeconds
            break;
          };
          # Highspeed Network
          default {
            Write-Verbose "Fast Network - calculating Sleep"
            $sleepSeconds = $remainingSeconds + 10;
            break;
          };
        } #$transferRate

      } #$transferRate

      switch ($Job.JobState)
      {
        "Connecting"
        {
          #Add-IHITimeStampPrefix ("Connecting: "+$transferPercent+" "+$mbit_s+" Remaining:"+$remainingSeconds+"s Sleeping:"+$sleepSeconds+"s");
          Add-IHITimeStampPrefix ("Connecting...");
          # During the connecting phase we shouldn't take too long and we will want
          # to output some progress before too long. So use a static value for this.
          #sleep $sleepSeconds;
          Start-Sleep 10;
          break;
        }
        "Transferring"
        {
          #Done Above#$percent = (($Job.BytesTransferred/$Job.BytesTotal)*100).ToString("F01")+"%";
          #$transferred = "("+($Job.BytesTransferred).ToString()+" of "+($Job.BytesTotal).ToString()+" bytes)";	
          #Done above#$mbit_s=Get-IHITransferRateBits -sizeInBytes $job.BytesTransferred -startDate $job.CreationTime -unit "Mb"
          Add-IHITimeStampPrefix ($transferPercent + " " + $mbit_s + " Remaining:" + $remainingSeconds + "s Sleeping:" + $sleepSeconds + "s");
          Start-Sleep $sleepSeconds;
          break;
        }
        "TransientError"
        {
          Add-IHITimeStampPrefix ("TransientError: Transfer interupted");
          Start-Sleep $sleepSeconds;
          break;
        }
        "Transferred"
        {
          Add-IHITimeStampPrefix ("Transfer Completed");
          break;
        }
        "Error"
        {
          Add-IHITimeStampPrefix ("Error");
          break;
        }
        default
        {
          Add-IHITimeStampPrefix ("Unhandled JobState: " + $Job.JobState);
          Start-Sleep $sleepSeconds;
        }
      } #switch

      # 2011.06.28 Mark Rovendro
      # I have been running into a situation where the JobState is not getting set to "Transferred"
      # even though the number of bytes of transferred equals the total bytes. So for now let's check
      # the JobState before quiting from this loop and see how that works.
      # until ($job.BytesTransferred -eq $job.BytesTotal -or $job.JobState -eq "Error")
    } until ($Job.JobState -eq "Transferred" -or $Job.JobState -eq "Error")

    Add-IHITimeStampPrefix ("Final JobState: " + $Job.JobState);

    switch ($Job.JobState)
    {
      "Transferred"
      {
        # $DurationTime is a [timespan] object, http://msdn.microsoft.com/en-us/library/ee372286.aspx
        $DurationTime = $Job.TransferCompletionTime - $Job.CreationTime;
        $mbit_s = Get-IHITransferRateBits -SizeInBytes $Job.BytesTransferred -StartDate $Job.CreationTime -EndDate $Job.TransferCompletionTime -Unit "Mb"
        $mbyte_s = Get-IHITransferRateBytes -SizeInBytes $Job.BytesTransferred -StartDate $Job.CreationTime -EndDate $Job.TransferCompletionTime -Unit "MB"
        Add-IHITimeStampPrefix ("Completed at " + $Job.TransferCompletionTime);
        Add-IHITimeStampPrefix ("Duration: " + $DurationTime.ToString() + " TotalMinutes:" + ($DurationTime.TotalMinutes).ToString("F01"));
        Add-IHITimeStampPrefix ("Transfer Rate: $mbit_s $mbyte_s");
        Complete-BitsTransfer -BitsJob $Job;
        break;
      }
      "Error"
      {
        # List the errors
        Add-IHITimeStampPrefix ("Error Description: " + $Job.ErrorDescription);
        Add-IHITimeStampPrefix ("Error Condition: " + $Job.ErrorCondition);
        break;
      }
      default
      {
        # Just kill the job if there is a problem and start again, this is not tested.
        Add-IHITimeStampPrefix ("Unknown Job State Removing Job");
        Remove-BitsTransfer -BitsJob $Job;
      }
    }
  }
  catch [System.Management.Automation.RuntimeException]
  {
    "Exception: $_.Exception.GetType().FullName"
    $_.Exception.Message
    Remove-BitsTransfer -BitsJob $Job
  }
  finally
  {
    Remove-Module BitsTransfer
  }
}
#endregion


#region Functions: Add-IHITimeStampPrefix

<#
.SYNOPSIS
Write message to host with timestamp prefix
.DESCRIPTION
Write message to host with timestamp prefix
.PARAMETER Message
Message to write
.EXAMPLE
Add-IHITimeStampPrefix -Message "Hello world"
Writes: 2011-11-15T11:02:02 Hello world
#>
function Add-IHITimeStampPrefix
{
  #region Function parameters
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false,ValueFromPipeline = $false)]
    [string]$Message
  )
  #endregion
  process {
    ((Get-Date).ToString("s") + " " + $Message)
  }
}
Export-ModuleMember -Function Add-IHITimeStampPrefix
#endregion
