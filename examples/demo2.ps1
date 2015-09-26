#similar to example 1, but now we're setting up a custom pattern using a PatternLayout object to a ConsoleAppender
#You can see here how to build a different Appender, although we're still using a ConsoleAppender (pretty boring)
Import-Module -Force $PSScriptRoot\..\..\log4ps
Clear-Log4PsConfiguration
$Pattern = "%date{dd-MM-yyyy }`t%logger [Line: %property{ScriptLineNumber}] %-5level [%x] - %message%newline"
Set-Log4PsRootLogger -Appender (New-Log4PSAppender -AppenderType ConsoleAppender -layout (New-Log4PSLayout -LayoutType PatternLayout -pattern $pattern) -Name 'ConsoleAppenderWithPattern')
$ErrorPreference = 'continue'
Write-Log4PsLog -message 'This is a test for a direct call to Log' -logLevel fatal
Write-Host 'This test is killing puppies'
Write-Verbose 'This is a verbose msg'
Write-Debug -Message 'Debug message'
Write-warning 'This is a WARN msg!'
Write-Error 'This is an error'
'this is STDOUT'

'This is killing puppies' | Write-Host 
'This is a verbose msg' | Write-Verbose
'Debug message' | Write-Debug
'This is a WARN msg' | Write-Warning
'This is an error' | Write-Error

throw 'This is an unhandled terminating error'