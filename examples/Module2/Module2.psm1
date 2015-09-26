Import-Module -Force $PSscriptRoot\..\SubModule2\SubModule2.psm1
function Test-Module2 {
	[cmdletBinding()]
	Param(
	)

	Process {
		Write-Host "`tModule2::TestModule2"
	}
}

function Test-Module2SubModule2 {
	Param(
	
	)
	Process {
		Write-host "`tModule2::TestModule2SubModule2"
		Test-SubModule2
	}
}