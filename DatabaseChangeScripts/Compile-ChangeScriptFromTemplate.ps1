Write-Host "`nLoading Function: Compile-ChangeScriptFromTemplate"

function Compile-ChangeScripts
{
  [CmdletBinding()] Param (
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MasterTemplatePath,
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$ContentTemplatePath,
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$OutputPath,
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$GitHash,
    [Parameter(ValueFromPipelineByPropertyName = $True)] [String]$TemplateVersion = "2.0"
  )
  try{
    Write-Host "Compiling ChangeScripts..."
    
    if ((Test-Path $MasterTemplatePath) -eq $false){
      throw "Path [$MasterTemplatePath] does not exist. Exiting..."
    }

    if ((Test-Path $ContentTemplatePath) -eq $false){
      throw "Path [$ContentTemplatePath] does not exist. Exiting..."
    }

    if ((Test-Path $OutputPath) -eq $false){
      Write-Host "Path [$OutputPath] does not exist. Creating..."
      New-Item $OutputPath -Force -ItemType Directory
    }

    # remove all files in output path
    Write-Host "Emptying post-compilation output path $OutputPath..."
    Remove-Item -Path (Join-Path -Path $OutputPath -ChildPath "\*") -Force
        
    foreach ($file in Get-ChildItem -path $ContentTemplatePath -Filter "*.sql" | sort-object )
    { 
      Write-Host "Compiling $file..."
      Compile-ChangeScriptFromTemplate -MasterTemplatePath $MasterTemplatePath -ContentTemplatePath (Join-Path -Path $ContentTemplatePath -ChildPath $file) -OutputPath $OutputPath -GitHash $GitHash -TemplateVersion $TemplateVersion #-InformationAction $InformationPreference
    }
    Write-Host "Compiled all ChangeScripts successfully"
  }
  catch {
    Write-Error "`nCompilating ChangeScripts failed with exception`n"
    Write-Error $_.Exception
    throw
  }
}

function Compile-ChangeScriptFromTemplate
{
  [CmdletBinding()] Param (
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MasterTemplatePath,
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$ContentTemplatePath,
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$OutputPath,
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$GitHash,
    [Parameter(ValueFromPipelineByPropertyName = $True)] [String]$TemplateVersion = "2.0"
  )

  try{
    Write-Host "`nCompiling Change Script V$TemplateVersion from Master Template [$MasterTemplatePath] and Content Template [$ContentTemplatePath] to [$OutputPath]..."

    #create a stopwatch to track script execution time
    $stopWatch = New-Object system.Diagnostics.Stopwatch 
    $stopWatch.Start()
    
    $compilationEnabled = $false

    # read content template
    try {
      $localContent = Get-Content $ContentTemplatePath
      Verify-TemplateVersion -Label "Content" -Content $localContent[0] -RequiredVersion $TemplateVersion
      $compilationEnabled = $true
    } catch [System.InvalidOperationException] {
      # this is potentially acceptable condition where a change script 
      # does not declare a template version because it should not be compiled
      Write-Warning $_.Exception
    }

    # determine if this change script should be compiled
    if ($compilationEnabled -eq $false){
      Write-Warning "ChangeScript with not be compiled with master template"

      $fileName = Split-Path -Path $ContentTemplatePath -Leaf
      $newPath = (Join-Path -Path $OutputPath -ChildPath $fileName)
      Write-Host "Writing compiled file to $newPath..."
      Copy-Item -Path $ContentTemplatePath -Destination $newPath -Force #-InformationAction $InformationPreference
      Write-Host "File Written"

      $stopWatch.Stop();  
      # Get the elapsed time as a TimeSpan value. 
      $ts = $stopWatch.Elapsed  
      # Format and display the TimeSpan value. 
      $ElapsedTime = [system.String]::Format("{0:00}:{1:00}:{2:00}.{3:00}", $ts.Hours, $ts.Minutes, $ts.Seconds, $ts.Milliseconds / 10); 
      Write-Host "`nElapsed Execution Time: $elapsedTime"
      Write-Host "Change Script compilation suceeded`n"
      return
    }

    # read master template
    $localResult = [Io.File]::ReadAllText($MasterTemplatePath)
    Verify-TemplateVersion -Label "Master" -Content $localResult -RequiredVersion $TemplateVersion
      
    # get replacement tokens hash
    $tokenHash = Get-TokenHash -MasterTemplatePath $MasterTemplatePath -ContentTemplatePath $ContentTemplatePath #-InformationAction $InformationPreference

    # replace tokens with token values in localResult
    Write-Host "`nReplacing Tokens with Values..."
    foreach($tokenKey in $tokenHash.Keys){
      $localResult = $localResult.Replace("TOKEN[$tokenKey]", $tokenHash[$tokenKey])
    }
    Write-Host "Replaced Tokens"

    #Write-Host "`n"
    #Write-Host $localResult

    # replace sections with section values in localResult
    $sectionHash = Get-SectionHash -MasterTemplatePath $MasterTemplatePath -ContentTemplatePath $ContentTemplatePath #-InformationAction $InformationPreference

    # replace sections with section values in localResult
    Write-Host "`nReplacing Sections with Values..."
    foreach($sectionKey in $sectionHash.Keys){
      $localResult = $localResult.Replace("SECTION[$sectionKey]", $sectionHash[$sectionKey])
    }
    Write-Host "Replaced Sections"
    
    #Write-Host "`n"
    #Write-Host $localResult

    # output localResult to output path
    $fileName = Split-Path -Path $ContentTemplatePath -Leaf
    $newPath = (Join-Path -Path $OutputPath -ChildPath $fileName)
    Write-Host "Writing compiled file to $newPath..."
    $null = $localResult | Out-File -FilePath $newPath -Force #-InformationAction $InformationPreference
    Write-Host "File Written"

    $stopWatch.Stop();  
    # Get the elapsed time as a TimeSpan value. 
    $ts = $stopWatch.Elapsed  
    # Format and display the TimeSpan value. 
    $ElapsedTime = [system.String]::Format("{0:00}:{1:00}:{2:00}.{3:00}", $ts.Hours, $ts.Minutes, $ts.Seconds, $ts.Milliseconds / 10); 
    Write-Host "`nElapsed Execution Time: $elapsedTime"
    Write-Host "Change Script compilation suceeded`n"

  }
  catch {
    Write-Error "`nChange Script compilation failed with exception`n"
    Write-Error $_.Exception
    throw
  }
}

function Verify-TemplateVersion {
  [CmdletBinding()] Param (
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Label,
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$Content,
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$RequiredVersion
  )

  try{
    Write-Host "Verifying Template Version of $Label..."

    $regexVersion = "CHANGE SCRIPT \w+ TEMPLATE V([\d|\.]+)"
    $null = $Content -match $regexVersion

    if($matches.Length -eq 0) {
      throw [System.InvalidOperationException] "$Label Template does not contain a Template Version."
    }

    if($matches.Length -gt 1) {
      throw "$Label Template contains multiple Template Versions."
    }

    if($matches[1] -ne $RequiredVersion) {
      throw "$Label template version V$($matches[1]) does not match required template version V$RequiredVersion."
    }

    Write-Host "Verified $Label version is V$($matches[1])"
  }
  catch {
    #Write-Error "`nVerification of Template Version failed`n"
    #Write-Error $_.Exception
    throw
  }
}

function Get-TokenHash {
  [CmdletBinding()] Param (
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MasterTemplatePath,
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$ContentTemplatePath
  )
  # define compiled regexes
  $regexToken = "TOKEN\[(.*?)\]"
  $regexTokenValueSuffix = ".+ = (.+)$"

  # find tokens specified in master
  Write-Host "`nFinding Tokens..."
  $tokens = Select-String -Pattern $regexToken -Path $MasterTemplatePath | Select -Expand Matches | Foreach { $_.Groups[1] } | Select -Expand Value | Sort-Object | Get-Unique | Sort-Object
  $tokens = $tokens += "DEPLOY_ENABLED"  #add Custom Token for CHANGE_STATUS
  Write-Host "Tokens Found:"
  $tokens | % {Write-Host $_}

  # for each token, find its corresponding value in localContent
  Write-Host "`nFinding Token Values..."
  $tokenHash = @{}
  foreach($token in $tokens){
    $regexTokenValue = $token + $regexTokenValueSuffix
    $result = Select-String -Pattern $regexTokenValue -Path $ContentTemplatePath | Select -Expand Matches -First 1

    if ($result -ne $null){
      $tokenHash[$token] = $result.Groups[1].Value
    } else {
      $tokenHash[$token] = [string].Empty
    }
  }
    
  # assign compile time token values
  if ($tokenHash.ContainsKey("GIT_HASH")){
    $tokenHash["GIT_HASH"] = $GitHash
  }
  if ($tokenHash.ContainsKey("COMPILATION_DATETIME")){
    $tokenHash["COMPILATION_DATETIME"] = Get-Date -Format s
  }
  if ($tokenHash.ContainsKey("CHANGE_STATUS")){
    if($tokenHash["DEPLOY_ENABLED"] -eq "1"){
      $tokenHash["CHANGE_STATUS"] = 100  #Deploy
    } else {
      $tokenHash["CHANGE_STATUS"] = 200  #Undeploy
    }
  }

  Write-Host "Token Values Found:"
  $tokenHash.Values | Where-Object {$_ -ne $null} | % {Write-Host $_}

  return $tokenHash
}

function Get-SectionHash {
  [CmdletBinding()] Param (
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$MasterTemplatePath,
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [String]$ContentTemplatePath
  )
  
  # define compiled section regex
  $regexSection = "SECTION\[(.*?)\]"

  # find sections specified in master
  Write-Host "`nFinding Sections..."
  $sections = Select-String -Pattern $regexSection -Path $MasterTemplatePath | Select -Expand Matches | Foreach { $_.Groups[1] } | Select -Expand Value | Sort-Object | Get-Unique | Sort-Object
  Write-Host "Sections Found:"
  $sections | % {Write-Host $_}

  # for each section, find its corresponding value in localContent
  $sectionContent = Get-Content $ContentTemplatePath | Out-String
  $sectionContentLength = $sectionContent.Length
  Write-Host "`nFinding Section Values..."
  $sectionHash = @{}
  foreach($section in $sections){
    $startSection = "/* SECTION[$section] BEGIN */"
    $endSection = "/* SECTION[$section] END */"
    $startSectionStartPosition = $sectionContent.IndexOf($startSection)
    $endSectionEndPosition = $sectionContent.IndexOf($endSection) + $endSection.Length
    $result = $sectionContent.Substring($startSectionStartPosition, ($endSectionEndPosition - $startSectionStartPosition))

    if ($result -ne $null){
      $sectionHash[$section] = $result
    } else {
      $sectionHash[$section] = [string].Empty
    }
  }
 
  Write-Host "Section Values Found:"
  $sectionHash.Values | Where-Object {$_ -ne $null} | % {Write-Host $_}

  return $sectionHash
}

Write-Host "Function Loaded: Compile-ChangeScriptFromTemplate"

#Examples of how to invoke this code
#$ENV:WORKSPACE = "C:\Repositories\FMI\FMI-Billing"
#$ENV:PIPELINE_VERSION = "testHash"
#$ENV:INFORMATION_ACTION = "Continue"
#Compile-ChangeScriptFromTemplate -MasterTemplatePath "$ENV:WORKSPACE\V1.0.0\FMI.Billing.Database\Templates\ChangeScript_Master_Template.sql" -ContentTemplatePath "$ENV:WORKSPACE\V1.0.0\FMI.Billing.Database\Templates\ChangeScript_Content_Template.sql" -OutputPath "C:\temp\" -GitHash "fakeHash" -TemplateVersion "2.0" -InformationAction "Continue"

$InformationPreference = "Continue"
Compile-ChangeScripts -MasterTemplatePath "$ENV:WORKSPACE\V1.0.0\FMI.Billing.Database\Templates\ChangeScript_Master_Template.sql" -ContentTemplatePath "$ENV:WORKSPACE\V1.0.0\FMI.Billing.Database\dbo\ChangeScripts\" -OutputPath "$ENV:WORKSPACE\V1.0.0\FMI.Billing.Database\dbo\ChangeScripts_PostCompile\" -GitHash "$ENV:PIPELINE_VERSION" -TemplateVersion "2.0" #-InformationAction "Continue"