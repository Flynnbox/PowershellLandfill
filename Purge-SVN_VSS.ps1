function Purge-SVNVSS {
    # set location of source folders
    param([string]$Source = "")
    if ($Source -eq "") {
     "Please specify the source directory to purge."
     exit
    }

    [string[]]$VssFileExtensions = ".scc",".vspscc",".vssscc"
    [string]$Name = $null


    # Step 1: purge any Subversion folders
    $Items = dir -path $Source -filter .svn -recurse -force | Where {$_.PSIsContainer -eq $true}
    if ($Items -eq $null) {
      "`n1. Purge SVN folders - none found!"
    } else {
      "`n1. Purging these SVN folders"
      $Items | foreach {
        $Name = $_.FullName
        "     " + $Name
        Remove-Item -path $Name -recurse -force
      }
    }

    # Step 2: purge any VSS source control files
    $Items = dir -path $Source -recurse -force | Where {$_.PSIsContainer -eq $false} | Where { $VssFileExtensions -contains $_.Extension }
    if ($Items -eq $null) {
      "`n2. Purge VSS files   - none found!"
    } else {
      "`n2. Purging these SVN folders"
      $Items | foreach {
        $Name = $_.FullName
        "     " + $Name
        Remove-Item -path $Name -force
      }
  
    }


    $Items = dir -path $Source -recurse -force | Where {$_.PSIsContainer -eq $false}
    if ($Items -eq $null) {
      "`n2. Set files readwrite - none found!"
    } else {
      "`n2. Setting these files readwrite"

      $Items | foreach {
        $File = $_
        "     " + $File.FullName
        $File.Attributes = [System.IO.FileAttributes] "Normal"
      }
  
    }
}
