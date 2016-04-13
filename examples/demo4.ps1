#This example shows the Hierarchy customization

#It is a bit painful to do this programatically, but this mainly to illustrate the concept of Hierarchy and different level
Import-Module -Force $PSScriptRoot\..\..\log4ps
Clear-Log4PsConfiguration #Start from fresh.

#Create a new Layout (simple uses a default pattern, you can change with: -LayoutType PatternLayout -Pattern "%date{dd-MM-yyyy }`t%logger [Line: %property{ScriptLineNumber}] %-5level [%x] - %message%newline")
$layout = New-Log4PSLayout -LayoutType SimpleLayout

#Create a Console appender (boring but simple) using the layout defined above.
$appender = New-Log4PSAppender -AppenderType ConsoleAppender -layout $layout -name MyConsoleAppender
$appender.ActivateOptions()

#set the root logger to use the appender, it will be used for all child loggers because Additivity is true by default
Set-Log4PsRootLogger -Appender $appender

#retrieve the root logger for the default repository. You can't use this logger directly.
$rootlogger = Get-Log4PsRootLogger
#define the level that will be logged
$rootlogger.level = [log4net.Core.Level]::info

#get a new logger named log, it will be appended to root automatically
$log = Get-Log4PSLogger -name 'Log'

#get another new logger named log2, we're adding it to the named repository (identical effect as above, as we're using the default repo)
$log2 = Get-Log4PSLogger -repository $rootlogger.Repository -name log2
#setting the level to FATAL only for this logger
$log2.Logger.Level = [log4net.Core.Level]::Fatal #anything under fatal will not be displayed


$log.Info('info from log')  #The Root logger is configured to log from 'INFO' and up, so this is displayed
$log2.Info('info from log2') #This will not output to the console because of the Level set to FATAL for $log2

$log.Fatal('Fatal from log')   #$Log.level -ge Fatal -> This will be displayed
$log2.Fatal('Fatal from log2') #$Log2.level -ge Fatal -> This will be displayed
