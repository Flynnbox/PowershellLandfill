
#region Module initialize
# initialize the module: re/set and script-level variables to defaults
function Initialize {
  [CmdletBinding()]
  param()
  process {
  }
}
# initialize/reset the module
Initialize
# ensure best practices for variable use, function calling, null property access, etc.
# must be done at module script level, not inside Initialize, or will only be function scoped
Set-StrictMode -Version 2
#endregion


#region Functions: Get-IHIHtmlEmailCssStyle1

<#
.SYNOPSIS
Gets HTML CSS Style block used in build/deploy emails
.DESCRIPTION
Gets HTML CSS Style block used in build/deploy emails
.EXAMPLE
Get-IHIHtmlEmailCssStyle1
Returns HTML CSS Style block used in build/deploy emails
#>
function Get-IHIHtmlEmailCssStyle1 {
  #region Function parameters
  [CmdletBinding()]
  param()
  #endregion
  process {
    $StyleString = @'
<STYLE>
  body {
    font-family: Verdana;
    font-size: 10pt;
  }
  table {
   width: 750px;
  }
  table .log {
  }
  tr {
    padding:0px;
  }
  td {
    padding: 5px;
    font-size: 10pt;
  }
  .log td {
    padding: 5px;
    font-size: 9pt;
    border-right:1px solid #000000;
    border-bottom:1px solid #000000;
  }
  th {
   border-top:1px solid #000000;
   border-right:1px solid #000000;
   border-bottom:1px solid #000000;
   padding: 5px;
   font-size:10pt;
   font-weight: bold;
   text-align: left;
  }
  .shaded {
   background-color: #cccccc;
  }
  .first {
   border-left:1px solid #000000;
   width: 20%;
  }
  h1 {
    font-size: 11pt;
    font-weight: bold;
    margin:0;
  }
  .label {
    font-weight: bold;
    text-align: left;
   width: 20%;
  }
</STYLE>
'@
    $StyleString
  }
}
Export-ModuleMember -Function Get-IHIHtmlEmailCssStyle1
#endregion
