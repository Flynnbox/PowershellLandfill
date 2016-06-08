#Get-ItemProperty -Path HKLM:"\SYSTEM\CurrentControlSet\Control\Keyboard Layout\"
#New-ItemProperty -Path HKLM:"\SYSTEM\CurrentControlSet\Control\Keyboard Layout\" -Name "Scancode Map" -PropertyType Binary -Value ([byte[]] (0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 81, 224, 83, 224, 73, 224, 81, 224, 83, 224, 73, 224, 0, 0, 0, 0))
