10/18/2014 - HL

PSCX2.1.1 = PSCX version 2.1.1 is required when using PowerShell v2. 
	This has been altered by IHI slightly, in that the PSCX.psd1 file has been renamed to be PSCX2.1.1.psd1. All else should be standard PSCX.
	The Import-IHIModules.ps1 file checks the version of PowerShell and if v2, it imports module PSCX2.1.1

PSCX = PSCX version 3.0.0 This is what the IHI PowerShell v3 Framework is generally using, so if you have PowerShell v3, this is what is currently used. 

PSCX3.1.0 = PSCX version 3.1.0, which seems to be necessary for PowerShell v4. It should also work with PowerShell v3, and we should be able to replace the PSCX directory with this one, but for safety sake, I'm adding it as a separate directory / module.
	This has been altered by IHI slightly, in that the PSCX.psd1 file has been renamed to be PSCX3.1.0.psd1. All else should be standard PSCX.
	The Import-IHIModules.ps1 file checks the version of PowerShell and if v4, it imports module PSCX3.1.0
	
Note: Rather than renaming these psd1 files, we could keep separate versions of PSCX (in PSCX sub-dirs like PSCXv2/PSCX, etc..) and then use the -RequiredVersion parameter of Import-Module, however, that would make the script a little more complex because we'd have to pass in an array of Module & RequiredVersion parameters and.... all modules would need to use RequiredVersion (or again.. the functions would have to be a bit more complex)


