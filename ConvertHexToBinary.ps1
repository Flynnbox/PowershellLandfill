function Convert-HexStringToByteArray {
	[CmdletBinding()]
	Param ( [Parameter(Mandatory = $True, ValueFromPipeline = $True)] [String] $String )

	#Clean out whitespaces and any other non-hex crud.
	$String = $String.ToLower() -replace '[^a-f0-9\\\,x\-\:]',''

	#Try to put into canonical colon-delimited format.
	$String = $String -replace '0x|\\x|\-|,',':'

	#Remove beginning and ending colons, and other detritus.
	$String = $String -replace '^:+|:+$|x|\\',''

	#Maybe there's nothing left over to convert...
	if ($String.Length -eq 0) { ,@() ; return } 

	#Split string with or without colon delimiters.
	if ($String.Length -eq 1)
	{ ,@([System.Convert]::ToByte($String,16)) }
	elseif (($String.Length % 2 -eq 0) -and ($String.IndexOf(":") -eq -1))
	{ ,@($String -split '([a-f0-9]{2})' | foreach-object { if ($_) {[System.Convert]::ToByte($_,16)}}) }
	elseif ($String.IndexOf(":") -ne -1)
	{ ,@($String -split ':+' | foreach-object {[System.Convert]::ToByte($_,16)}) }
	else
	{ ,@() }
	#The strange ",@(...)" syntax is needed to force the output into an
	#array even if there is only one element in the output (or none).
}

#Convert-HexStringToByteArray "00,00,00,00,00,00,00,00,04,00,00,00,51,e0,53,e0,49,e0,51,e0,53,e0,49,e0,00,00,00,00"