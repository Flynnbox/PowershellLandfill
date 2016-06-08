function Run-SublimeText3 {
 &"${Env:ProgramFiles}\Sublime Text 3\sublime_text.exe" $args 
}

Set-Alias s3 Run-SublimeText3 -scope global