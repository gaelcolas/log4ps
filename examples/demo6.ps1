#This file is to demo different type of appender
#remember, by default the module is looking for a config file, here .\demo6.ps1.config
Import-Module -Force $PSScriptRoot\..\..\log4ps

Write-Host 'This test is killing puppies'
Write-Verbose 'This is a verbose msg'
Write-Debug -Message 'Debug message'
Write-warning 'This is a WARN msg!'
Write-Error 'This is an error'

Get-Content $env:TMP\example.log

#find other example of file appender here: https://logging.apache.org/log4net/release/config-examples.html