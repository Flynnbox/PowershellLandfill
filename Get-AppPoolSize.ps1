function Get-AppPoolSize {
    $AppPoolName = "LMS"

    # name of server
    $Server = "DAA10197WWW006.ihi.com"

    function Get-IhiAppPoolProcessIdOnRemoteServer {
      #region Function parameters
      [CmdletBinding()]
      param(
      [string]$ComputerName,
      [string]$AppPool
      )
      #endregion
      process {
        $Id = 0
        $WebProcesses = Get-Process -ComputerName $ComputerName -Name "W3WP"
        # look through all web processes
        $WebProcesses | ForEach-Object {
          # use WMI API to get process details
          $Filter = "Handle='" + $_.Id + "'"
          $Wmip = Get-WmiObject Win32_Process -Filter $Filter -ComputerName $ComputerName
          # CommandLine property has AppPool name; grab name using regex
          if($Wmip.CommandLine -match '-ap "([^"]+)"') {
            # if name matches, grab id
            if ($matches[1].ToUpper() -eq $AppPool.ToUpper()) {
              $Id = $_.Id
            }
          }
        }
        $Id
      }
    }

    $ProcessId = Get-IhiAppPoolProcessIdOnRemoteServer -ComputerName $Server -AppPool $AppPoolName
    $Memory = (Get-Process -Id $ProcessId -ComputerName $Server).PrivateMemorySize
    $Memory
}