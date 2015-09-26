# This example highlights how to use the module in the simplest way.
# The default behaviour is a ConsoleAppender with a SimpleLayout (Default pattern)
# Not very useful, but great for test and getting started.
# You will see in further example how to change the pattern [demo2.ps1],
# Then how it behaves in nested calls, when you call from other modules, nested modules, or dot sourcing [demo3.ps1]
# add more logger and customize their use through filters [demo4.ps1] ,
# configure a simple file appender to target files ,
# and finally how to configure all those config via XML file.
# Eventually you won't need more than the following line to include customized logging to your scripts

Import-Module -Force $PSScriptRoot\..\..\log4ps
'test STDOUT'
#Shows how normal writing to error stream work. Only need to import the module
Write-Host 'This test is killing puppies'
Write-Verbose 'This is a verbose msg'
Write-Debug -Message 'Debug message'
Write-warning 'This is a WARN msg!'
Write-Error 'This is an error'

#Proving they work via the pipeline as well
'This is killing puppies' | Write-Host 
'This is a verbose msg' | Write-Verbose
'Debug message' | Write-Debug
'This is a WARN msg' | Write-Warning
'This is an error' | Write-Error

#You can also call the log function directly, without going through the Microsoft.PowerShell.Utility commands
Write-Log4PsLog -message 'This is a test for a direct call to Log' -logLevel fatal -loggerName 'DATABASE'

throw 'This is an unhandled stopping error'