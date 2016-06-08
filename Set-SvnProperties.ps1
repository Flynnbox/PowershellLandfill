#do not run this code on powershell startup
return

function Set-SvnProperties {
   [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [Alias("AliasName")]
    [string]$ParameterName
  )

  $SvnCommandText = ""

  try{

  }catch{
    $ErrorMessage = $_.Exception.Message
    Write-Host "An Error Occured" -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red
  }finally{

  }
}

#get all mime-type properties from svn and write to file
svn propget -r HEAD -R --xml svn:mime-type 'http://engbuild.ihi.com/svn/ihi_main/trunk' > SVN-Mime-Type.xml

#read mime-type properties into local variable
[xml]$mimeTypes = get-content -path SVN-Mime-Type.xml

#get unique list of all file extensions for all binary files
$uniqueFileExtensions = $mimeTypes.SelectNodes('//target[@path][property = "application/octet-stream"]') | % { $_.path.Substring($_.path.LastIndexOf(".")).ToLower() } | sort-object | get-unique

#get all binary files with specified file extensions
$urlsToUpdate = $mimeTypes.SelectNodes('//target[@path][property = "application/octet-stream"]') | % { $_.path } | where { $_ -match "\.(htm|html|css|js|cs|txt|udf|sql|prc|viw|xml|xslt|aspx|ascx|config|log|ps1)$"}
$urlsToUpdate > SVN-BinaryFileUrlsToUpdate.txt

#set svn property of files to mime-type 'text/plain; charset=UTF-8'
foreach($url in $urlsToUpdate){  
  svnmucc propset svn:mime-type 'text/plain; charset=UTF-8' $url -m "svn:mime-type property updated to 'text/plain; charset=UTF-8'"
}