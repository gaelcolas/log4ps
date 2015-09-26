$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe 'Load log4ps module' {
	It 'does not Error at loading'{
		{ Import-Module $here/../../log4ps -Force } | Should not throw
	}
	It 'load the log4net binary' {
		Import-Module $here/../../log4ps -Force
		[System.Reflection.Assembly]::GetAssembly([log4net.LogManager]) | Should Not BeNullOrEmpty
	}
}

Describe 'Get-Log4PsRootLogger' {
	It 'returns an object of type log4net.Repository.Hierarchy.RootLogger' {
		(Get-Log4PsRootLogger).GetType() | Should be ([log4net.Repository.Hierarchy.RootLogger])
	}
	It 'has no parent' {
		(Get-Log4PsRootLogger).parent | Should beNullOrEmpty
	}
}

Describe 'Get-Log4PSLogger' {
	$loggerName = 'Test'
	It 'does not accept empty parameters' {
		{ Get-Log4PSLogger } | Should throw 'Parameter set cannot be resolved using the specified named parameters.'
	}
	It 'returns an object of type log4net.Core.LogImpl' {
		(Get-Log4PSLogger -name $loggerName).GetType() | Should be ([log4net.Core.LogImpl])
	}
	It "has a Logger named $loggerName" {
		(Get-Log4PSLogger -name $loggerName).logger.Name | Should be $loggerName
	}
	It 'has the root logger for parent' {
		(Get-Log4PSLogger -name $loggerName).Logger.parent -eq (Get-Log4PsRootLogger) | Should be $true
	}
	It 'has at least 6 parameter set name' {
		((Get-Command Get-Log4PSLogger).ParameterSets).count -ge 6 | Should be $true
	}
	
	BeforeEach {
		Import-Module $here/../../log4ps -Force #will erase the configuration
	}
}

Describe 'Enums' {

	It 'adds log4psAppender enum entry for each Appender extending AppenderSkeleton' {
		$availableAppenders = ([reflection.assembly]::GetAssembly([log4net.Appender.AppenderSkeleton]).DefinedTypes) | Where-Object { $_.IsSubclassOf([log4net.Appender.AppenderSkeleton]) -and -not $_.isAbstract}
		Compare-object ([System.Enum]::GetNames([log4net.Appender.Log4PSAppender])) $availableAppenders.Name | Should BeNullOrEmpty
	}
	
	It 'adds log4psAppender enum entry for each Appender extending AppenderSkeleton' {
		$availableLayouts = ([reflection.assembly]::GetAssembly([log4net.Layout.LayoutSkeleton]).DefinedTypes) | Where-Object { $_.IsSubclassOf([log4net.Layout.LayoutSkeleton]) -and -not $_.isAbstract}
		Compare-object ([System.Enum]::GetNames([log4net.Layout.Log4PSLayout])) $availableLayouts.Name | Should BeNullOrEmpty
	}
	
	It 'adds the Argument Enum as a dirty workaround' {
		#This is a (dirty) workaround when generating dynamic parameter to allow a function to have an empty signature:
		# Do-Something() as well as a signature with multiple mandatory parameters
		# Do-Something(Arg1,Arg2)
		# The nicer workaround yet to be implemented is using an undefined DefaultParameterSetName
		# But I have yet to find how you can set this in your DynamicParam block (reflection?)
		{ [Argument] } | Should not throw
	}

}

Describe 'New-Log4psLayout' {


}

Describe 'New-Log4psAppender' {

}

Describe 'Clear-Log4psConfiguration' {

}

Describe 'Reset-Log4psConfiguration' {

}

