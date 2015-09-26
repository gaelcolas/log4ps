#this example shows the use of an XML file
#look at demo5.ps1.config.xml
#This is the prefered way to load a config file, log4net will by default monitor changes to that file.
#If the config file change, the logging will reflect the changes (you can, for instance change the Log level on the fly for a specific logger)
Import-Module -Force $PSScriptRoot\..\..\log4ps
'This will show on the appender because the config file LEVEL is set to FATAL' | Write-Log4PsLog -logLevel fatal

#look at the alternate config file, we override by giving the file path as parameter in hashtable
Import-Module -Force $PSScriptRoot\..\..\log4ps -ArgumentList @{'ConfigFile'="$PSScriptRoot\demo5.ps1.alternate.config.xml";'dontwatch'=$true}
'This will not show on the appender, the Alternate config file has LEVEL set to OFF' | Write-Log4PsLog -logLevel fatal


#Note the Alternate2 config, we're passing only one parameter, and it's the config file.
Import-Module -Force $PSScriptRoot\..\..\log4ps -ArgumentList "$PSScriptRoot\demo5.ps1.alternate2.config.xml"
'This will show on the appender, the Alternate config file has LEVEL set to INFO' | Write-Log4PsLog -logLevel info