
function Test-Module1 {
	[cmdletBinding()]
	Param(
	)

	Process {
		Write-Host "`tModule1::TestModule1"
		$s = (Get-PSCallStack) 
	
	}
}

