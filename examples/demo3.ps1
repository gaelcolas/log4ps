#This example is to show how the logging behave in Nested calls
# The Property PSCallStack is defined in log4ps.psm1 -> Write-Log4psLog function
# Same goes for ScriptLineNumber
Import-Module -Force $PSScriptRoot\..\..\log4ps
Clear-Log4PsConfiguration #clearing the configuration to start from fresh
$Pattern = "%date{dd-MM-yyyy }`t%logger [Line: %property{ScriptLineNumber}] %-5level - %message `t(%property{PSCallStack})%newline"
Set-Log4PsRootLogger -Appender (New-Log4PSAppender -AppenderType ConsoleAppender -layout (New-Log4PSLayout -LayoutType PatternLayout -pattern $pattern) -Name 'ConsoleAppenderWithPattern')

######## The rest of the code is not specific to logging. It 'just happen'

Import-Module $PSScriptRoot\Module1\Module1.psm1
#Test-Module1

function Test-CallStackExample1 {
	. { #DotSourcing the scriptblock to show that <scriptblock> is ignored from the PSCallStack log4net property
		Write-Verbose -Message 'This is the Test-CallStackExample'
		Test-Module1
	}
}

Test-CallStackExample1

Import-Module -force $PSScriptRoot\Module2\Module2.psm1
function Test-CallStackModule2 {
	$mod = Get-Module -Name Module2 #just for debug to prove that module2 has nested module
	#Write-Host "Module2 has a NestedModule: $($mod.NestedModules)"
	Test-Module2
	Test-Module2SubModule2
}
Test-CallStackModule2

. $PSScriptRoot\dotsourced.ps1

Test-DotSourced
