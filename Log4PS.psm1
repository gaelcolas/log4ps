#region HEADER: To accept arguments, the very first line of code must be Param(), then catch those in a var for re-use
param ()
$script:ModuleParams = $args
#endregion

#With Set-<modulename>Config as standard, create a TabPlusPlus extension to auto populate hashtable in -argumentlist
#capture arguments during module loading

$script:CommandLevelMap = @{'Write-Host'='info';'Write-Debug'='debug';'write-Verbose'='info';'Write-Warning'='warn';'Write-Error'='error'}

#region Generic Helper functions
. $PSscriptroot\lib\lib.common\ReceiveModuleParams.ps1
. $PSScriptroot\lib\lib.common\PowerObject.ps1
. $PSScriptRoot\lib\lib.common\MethodHelpers.ps1
. $PSScriptRoot\lib\lib.common\TypeHelpers.ps1
. $PSScriptRoot\lib\lib.common\NewGuid.ps1
#endregion

#region Enums

#region Create enum from Appender types
if(-not ('log4net.Appender.Log4PSAppender' -as [Type])) {
 $availableAppenders = ([reflection.assembly]::GetAssembly([log4net.Appender.AppenderSkeleton]).DefinedTypes) | Where-Object { $_.IsSubclassOf([log4net.Appender.AppenderSkeleton]) -and -not $_.isAbstract}
 $AppenderTypeEnum = @" 
namespace log4net.Appender {
	public enum Log4PSAppender 
	{
	$($availableAppenders.Name -join ",`r`n" )
	}
}
"@
 Add-Type -TypeDefinition $AppenderTypeEnum -ErrorAction SilentlyContinue
 Remove-Variable -Name availableAppenders -Force
}
#endregion

#region Create Enum from Layout types

if(-not ('log4net.Layout.Log4PSLayout' -as [Type])) {
 $availableLayouts = ([reflection.assembly]::GetAssembly([log4net.Layout.LayoutSkeleton]).DefinedTypes) | Where-Object { $_.IsSubclassOf([log4net.Layout.LayoutSkeleton]) -and -not $_.isAbstract}
 $LayoutTypeEnum = @" 
namespace log4net.Layout {
	public enum Log4PSLayout 
	{
	$($availableLayouts.Name -join ",`r`n" )
	}
}
"@
 Add-Type -TypeDefinition $LayoutTypeEnum -ErrorAction SilentlyContinue
 Remove-Variable -Name availableLayouts -Force
}
#endregion


#endregion

Function Get-RootLogger {
 [cmdletBinding()]
 [OutputType([log4net.ILog])]
 Param(
		
 )
 [log4net.LogManager]::GetRepository().root
}

function Set-RootLogger {
 [cmdletBinding()]
 [OutputType([void])]
 Param(
  [Parameter(ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true, Mandatory = $false, Position=0)]
  [log4net.Appender.IAppender]
  $Appender = (New-Appender -AppenderType ConsoleAppender  -Name ConsoleAppender -layout (New-Layout -LayoutType SimpleLayout))
 )
 Process {
  $Appender.activateOptions()
  $root = [log4net.LogManager]::GetRepository().root
  $root.AddAppender($Appender)
  $root.Hierarchy.configured = $true
 }

}

function Set-ModuleConfig {
 [cmdletBinding(DefaultParameterSetName='IncludeProxy')]
 [outputType([void])]
 param (
  [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName = $true)]
  [Alias('FullName','Path')]
  [string]
  $configFile = $script:ConfigFile,
		
  [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName = $true)]
  [switch]
  $dontWatch,
		
  [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName = $true)]
  [hashtable]
  $ProxyLevelMap = $script:CommandLevelMap,
  
  [switch]
  $excludeWriteProxyFunction,
  
  [switch]
  $Log4netInternalDebug
 )
 process {
   $ModuleName = $PSCmdlet.MyInvocation.MyCommand.Module.Name
   
  if($Log4netInternalDebug) {
   [log4net.Util.LogLog]::InternalDebugging = $true
  }
  else {
   [log4net.Util.LogLog]::InternalDebugging = $false
  }
  
  Clear-Configuration
  if($PSBoundParameters.ContainsKey('ProxyLevelMap')) {
   $script:CommandLevelMap = $ProxyLevelMap
  }
  #$script:CommandLevelMap = $ProxyLevelMap
		
  if($configFile -and -not $dontWatch) {
   [log4net.Config.XmlConfigurator]::ConfigureAndWatch((Get-Item $configFile))
  }
  elseif($configFile) {
   [log4net.Config.XmlConfigurator]::Configure((Get-Item $configFile))
  }
  else {
   Set-RootLogger
  }
  #NOT IMPLEMENTED YET
  if($excludeWriteProxyFunction) {
   'The Write-* functions will NOT be proxied to Log4Net (and removed)'| Write-Verbose
   foreach ($aliasName in (Get-Command -Module $ModuleName -CommandType Alias -Name 'Write-*').Name) {
    Remove-Item "alias:$aliasName" -Force -ErrorAction SilentlyContinue
   }
  }
  else {
   Register-Aliases -ModuleName $PSCmdlet.MyInvocation.MyCommand.Module.Name -Prefix 'Log4PS' #cuz you can't get prefix while module loading :(
  }
 }
}

function Register-Aliases {
 [CmdletBinding()]
 Param(
  [string]
  $ModuleName = $PSCmdlet.MyInvocation.MyCommand.Module.Name,
  [string]
  $Prefix = $PSCmdlet.MyInvocation.MyCommand.Module.Prefix,
  [string[]]
  [ValidateSet('Write-Host','Write-Verbose','Write-Debug','Write-Warning','Write-Error','out-default','Write-Log')] 
  $Streams = @('Write-Host','Write-Verbose','Write-Debug','Write-Warning','Write-Error','out-default','Write-Log')
 )

 Process {
  foreach($aliasName in $streams) {
   Remove-Item "alias:$aliasName" -Force -ErrorAction SilentlyContinue
   $verb = ($aliasName -split '-')[0]
   $noun = ($aliasName -split '-')[1] 
   Set-Alias -Scope Global -Name $aliasName -Value "$ModuleName\$verb-${prefix}$noun"
  }
 }
}

function Get-Logger {
 [CmdletBinding()]
 param
 (

 )
 DynamicParam {
  Get-DynamicParamForMethod -method ([log4net.LogManager]::GetLogger)
 }
	
 process
 {
  try
  {
   Invoke-MethodOverloadFromBoundParam -method ([log4net.LogManager]::GetLogger) -parameterSet $PSCmdlet.ParameterSetName -Parameters $PSBoundParameters
  }
  catch
  {
   Write-Warning "Error occured: $_"
   Throw $_
  }
 }
}

#region Write-Log for log4ps
function Write-Log {
 [cmdletBinding()]
 [OutputType([void])]
 Param(
  $loggerName,
  [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true,ValueFromPipeline = $true)]
  $message,
  [ValidateSet('debug','info','warn','error','fatal')]
  $logLevel = 'info',
  [hashtable]
  $properties = @{}
  #,$proxiedLoggedCmd = @('Write-Error','Write-Debug','Write-Verbose','Write-Host')
 )
 Begin {
  $prefix = $PSCmdlet.MyInvocation.MyCommand.Module.Prefix
 }
 Process {
  #TODO: organically grown--> To refactor!
  $CallStack = (Get-PSCallStack)
  if($CallStack[1].Command -eq 'Out-Default' -or (Get-Command -Name $CallStack[1].Command -ea SilentlyContinue).ModuleName -eq 'log4ps') { #internal module caller, such as proxy function
   $PSCallStackIndex = 2
  }
  else {
   $PSCallStackIndex = 1
  }
  if($message.GetType() -eq [System.Management.Automation.ErrorRecord]) {
   $loggerName = $message.InvocationInfo.ScriptName | Split-Path -Leaf
   $ScriptLineNumber = $message.InvocationInfo.ScriptLineNumber.ToString()
  }
  elseif(-not $loggerName -and $CallStack[$PSCallStackIndex].ScriptName) { #no explicit logger -> autoresolve
   $loggerName = $CallStack[$PSCallStackIndex].ScriptName | Split-Path -Leaf
   $ScriptLineNumber = $CallStack[$PSCallStackIndex].ScriptLineNumber.ToString()
  }
  elseif (-not $loggerName ) {
   $loggerName = 'CLI'
   $ScriptLineNumber = 'console'
  }
  $logger = Get-Logger -name $loggerName
  if ($logger."is$($Loglevel)Enabled")
  {
   $CommandCallStack =($CallStack[$PSCallStackIndex..($CallStack.Count -1)]| Where-Object {$_.command -notmatch '<scriptblock>'}).Command
   if($CommandCallStack) {
    [array]::Reverse($CommandCallStack)
   }
   #[log4net.ThreadContext]::Stacks['Stack'].Push()
   [log4net.ThreadContext]::Properties['ScriptLineNumber'] = $ScriptLineNumber
   [log4net.ThreadContext]::Properties['PSCallStack'] = $CommandCallStack -join ' => '

   #Microsoft.PowerShell.Utility\Write-Debug "Logger: $Logger    CommandStack: $($CommandCallStack -join ' => ')"
   foreach($msg in $message) {
    $logger.($logLevel)($message)
   }
			
  }
 }
}
#endregion

#region proxy functions 
#TODO: Make them conditional, and probably generate them dynamically

#region Write Host Proxy
function Write-Host {

 [CmdletBinding(HelpUri='http://go.microsoft.com/fwlink/?LinkID=113426', RemotingCapability='None')]
 param(
  [Parameter(Position=0, ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
  [System.Object]
  ${Object},

  [switch]
  ${NoNewline},

  [System.Object]
  ${Separator},

  [System.ConsoleColor]
  ${ForegroundColor},

  [System.ConsoleColor]
 ${BackgroundColor})

 begin
 {
  try {
   $outBuffer = $null
   if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
   {
    $PSBoundParameters['OutBuffer'] = 1
   }
   $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Write-Host', [System.Management.Automation.CommandTypes]::Cmdlet)
   $scriptCmd = {& $wrappedCmd @PSBoundParameters }
   $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
   $steppablePipeline.Begin($PSCmdlet)
  } catch {
   throw
  }
 }

 process
 {
  foreach ($obj in $object)
  {
   try {
    Write-Log -message $obj -logLevel $script:CommandLevelMap['Write-Host']
    $steppablePipeline.Process($obj)
   } catch {
    throw
   }
  }
 }

 end
 {
  try {
   $steppablePipeline.End()
  } catch {
   throw
  }
 }
 <#

   .ForwardHelpTargetName Microsoft.PowerShell.Utility\Write-Host
   .ForwardHelpCategory Cmdlet

 #>

}
#endregion

#region Write-Debug proxy
function Write-Debug {
 [CmdletBinding(HelpUri='http://go.microsoft.com/fwlink/?LinkID=113424', RemotingCapability='None')]
 param(
  [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
  [Alias('Msg')]
  [AllowEmptyString()]
  [string]
 ${Message})

 begin
 {
  try {
   $outBuffer = $null
   if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
   {
    $PSBoundParameters['OutBuffer'] = 1
   }
   $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Write-Debug', [System.Management.Automation.CommandTypes]::Cmdlet)
   $scriptCmd = {& $wrappedCmd @PSBoundParameters }
   $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
   $steppablePipeline.Begin($PSCmdlet)
  } catch {
   throw
  }
 }

 process
 {
  foreach ($msg in $message)
  {
   try {
    Write-Log -message $msg -logLevel $script:CommandLevelMap['Write-Debug']
    $steppablePipeline.Process($msg)
   } catch {
    throw
   }
  }
		

 }

 end
 {
  try {
   $steppablePipeline.End()
  } catch {
   throw
  }
 }
 <#

   .ForwardHelpTargetName Microsoft.PowerShell.Utility\Write-Debug
   .ForwardHelpCategory Cmdlet

 #>
}
#endregion

#region Write-Verbose proxy
function Write-Verbose {
 [CmdletBinding(HelpUri='http://go.microsoft.com/fwlink/?LinkID=113429', RemotingCapability='None')]
 param(
  [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
  [Alias('Msg')]
  [AllowEmptyString()]
  [string]
 ${Message})

 begin
 {
  try {
   $outBuffer = $null
   if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
   {
    $PSBoundParameters['OutBuffer'] = 1
   }
   $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Write-Verbose', [System.Management.Automation.CommandTypes]::Cmdlet)
   $scriptCmd = {& $wrappedCmd @PSBoundParameters }
   $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
   $steppablePipeline.Begin($PSCmdlet)
  } catch {
   throw
  }
 }

 process
 {
  foreach ($msg in $message)
  {
   try {
    Write-Log -message $msg -logLevel $script:CommandLevelMap['Write-Verbose']
    $steppablePipeline.Process($msg)
   } catch {
    throw
   }
  }
 }

 end
 {
  try {
   $steppablePipeline.End()
  } catch {
   throw
  }
 }
 <#

   .ForwardHelpTargetName Microsoft.PowerShell.Utility\Write-Verbose
   .ForwardHelpCategory Cmdlet

 #>
}
#endregion

#region Write-Warning proxy
function Write-Warning {
 [CmdletBinding(HelpUri='http://go.microsoft.com/fwlink/?LinkID=113430', RemotingCapability='None')]
 param(
  [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
  [Alias('Msg')]
  [AllowEmptyString()]
  [string]
 ${Message})

 begin
 {
  try {
   $outBuffer = $null
   if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
   {
    $PSBoundParameters['OutBuffer'] = 1
   }
   $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Write-Warning', [System.Management.Automation.CommandTypes]::Cmdlet)
   $scriptCmd = {& $wrappedCmd @PSBoundParameters }
   $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
   $steppablePipeline.Begin($PSCmdlet)
  } catch {
   throw
  }
 }

 process
 {
  foreach ($msg in $message)
  {
   try {
    Write-Log -message $msg -logLevel $script:CommandLevelMap['Write-Warning']
    $steppablePipeline.Process($message)
   } catch {
    throw
   }
  }
		
 }

 end
 {
  try {
   $steppablePipeline.End()
  } catch {
   throw
  }
 }
 <#

   .ForwardHelpTargetName Microsoft.PowerShell.Utility\Write-Warning
   .ForwardHelpCategory Cmdlet

 #>
}
#endregion

#region Write-Error proxy
function Write-Error {
 [CmdletBinding(DefaultParameterSetName='NoException', HelpUri='http://go.microsoft.com/fwlink/?LinkID=113425', RemotingCapability='None')]
 param(
  [Parameter(ParameterSetName='WithException', Mandatory=$true)]
  [System.Exception]
  ${Exception},

  [Parameter(ParameterSetName='NoException', Mandatory=$true, Position=0, ValueFromPipeline=$true)]
  [Parameter(ParameterSetName='WithException')]
  [Alias('Msg')]
  [AllowEmptyString()]
  [AllowNull()]
  [string]
  ${Message},

  [Parameter(ParameterSetName='ErrorRecord', Mandatory=$true)]
  [System.Management.Automation.ErrorRecord]
  ${ErrorRecord},

  [Parameter(ParameterSetName='NoException')]
  [Parameter(ParameterSetName='WithException')]
  [System.Management.Automation.ErrorCategory]
  ${Category},

  [Parameter(ParameterSetName='NoException')]
  [Parameter(ParameterSetName='WithException')]
  [string]
  ${ErrorId},

  [Parameter(ParameterSetName='WithException')]
  [Parameter(ParameterSetName='NoException')]
  [System.Object]
  ${TargetObject},

  [string]
  ${RecommendedAction},

  [Alias('Activity')]
  [string]
  ${CategoryActivity},

  [Alias('Reason')]
  [string]
  ${CategoryReason},

  [Alias('TargetName')]
  [string]
  ${CategoryTargetName},

  [Alias('TargetType')]
  [string]
 ${CategoryTargetType})

 begin
 {
  try {
   $outBuffer = $null
   if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
   {
    $PSBoundParameters['OutBuffer'] = 1
   }
   $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Write-Error', [System.Management.Automation.CommandTypes]::Cmdlet)
   $scriptCmd = {& $wrappedCmd @PSBoundParameters }
   $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
   $steppablePipeline.Begin($PSCmdlet)
  } catch {
   throw
  }
 }

 process
 {
  foreach ($msg in $message)
  {
   try {
    Write-Log -message $msg -logLevel $script:CommandLevelMap['Write-Error']
    $steppablePipeline.Process($msg)
   } catch {
    throw
   }
  }
 }

 end
 {
  try {
   $steppablePipeline.End()
  } catch {
   throw
  }
 }
 <#

   .ForwardHelpTargetName Microsoft.PowerShell.Utility\Write-Error
   .ForwardHelpCategory Cmdlet

 #>
}
#endregion

#region Out-Default proxy
 function Out-Default {
  [CmdletBinding(HelpUri='http://go.microsoft.com/fwlink/?LinkID=113362', RemotingCapability='None')]
  param(
   [switch]
   ${Transcript},

   [Parameter(ValueFromPipeline=$true)]
   [psobject]
  ${InputObject})

  begin
  {
   try {
    $outBuffer = $null
    if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
    {
     $PSBoundParameters['OutBuffer'] = 1
    }
							
    $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Core\Out-Default', [System.Management.Automation.CommandTypes]::Cmdlet)
    $scriptCmd = {& $wrappedCmd @PSBoundParameters }
    $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
    $steppablePipeline.Begin($PSCmdlet)
   } catch {
    throw
   }
  }

  process
  {
   foreach($obj in $InputObject) {
    try {
     if($obj.getType() -eq [System.Management.Automation.ErrorRecord]) {
      $loglevel = 'FATAL'
     }
     else{
      $loglevel = 'INFO'
     }
     Write-Log -message $obj -logLevel $loglevel
     $steppablePipeline.Process($obj)
    } catch {
     throw
    }
   }
  }

  end
  {
   try {
    $steppablePipeline.End()
   } catch {
    throw
   }
  }
  <#

    .ForwardHelpTargetName Microsoft.PowerShell.Core\Out-Default
    .ForwardHelpCategory Cmdlet

  #>
 }
#endregion

#endregion



#region log4net Layout
function New-Layout {
 [cmdletBinding()]
 Param (
  [Parameter(Mandatory=$false,ValueFromPipeLine=$false,ValueFromPipelineByPropertyName=$true, position=0)]
  [log4net.Layout.Log4PSLayout]
  $LayoutType = [log4net.Layout.Log4PSLayout]::SimpleLayout
 )
 DynamicParam {
  if ($PSBoundParameters.Keys -notcontains 'LayoutType')
  {
   $LayoutType = [log4net.Layout.Log4PSLayout]::SimpleLayout
  }
  $type = ("log4net.Layout.$LayoutType" -as [Type])
  Get-DynamicParamFromTypeName -TypeName $type.ToString()
 }
	
 Process {
  New-ObjectInstanceFromTypeNameAndBoundParams -TypeName "log4net.Layout.$LayoutType" -StaticArgumentName 'LayoutType' -ParameterSetName $PSCmdlet.ParameterSetName -BoundParameters $PSBoundParameters
 }
}
#endregion

#region log4net Appender
function New-Appender {
 [cmdletBinding()]
 [outputType([log4net.Appender.IAppender])]
 Param (
  [Parameter(Mandatory=$true,ValueFromPipeLine=$false,ValueFromPipelineByPropertyName=$true, position=0)]
  [log4net.Appender.Log4PSAppender]
  $AppenderType
 )
 DynamicParam {
  if($type = ("log4net.Appender.$AppenderType" -as [Type])) {
   Get-DynamicParamFromTypeName -TypeName $type.ToString()
  }
 }
	
 Process {
  New-ObjectInstanceFromTypeNameAndBoundParams -TypeName "log4net.Appender.$AppenderType" -StaticArgumentName 'AppenderType' -ParameterSetName $PSCmdlet.ParameterSetName -BoundParameters $PSBoundParameters
 }
}
#endregion


#region log4net Config BasicConfigurator Configure

# Overload #1: no params
# Overload #2: appender
# Overload #3: AppenderS
# Overload #4: repository
# Overload #5: repository and appender
# Overload #6: repository and appenderS
function Set-BasicConfiguration
{
 [CmdletBinding()]
 param
 (
	
 )
 DynamicParam {
  Get-DynamicParamForMethod -method ([log4net.Config.BasicConfigurator]::Configure)
 }
	
 process
 {
  try
  {
   Invoke-MethodOverloadFromBoundParam -method ([log4net.Config.BasicConfigurator]::Configure) -parameterSet $PSCmdlet.ParameterSetName -Parameters $PSBoundParameters
  }
  catch
  {
   Write-Warning "Error occured: $_"
   throw $_
  }
 }
}
#endregion

#region log4net Config XmlConfigurator configure

# Overload #1: No Parameter
# Overload #2: repository
# Overload #3: element
# Overload #4: repository and element
# Overload #5: ConfigFile
# Overload #6: URI
# Overload #7: ConfigStream
# Overload #8: Repository and Configfile
# Overload #9: Repository and ConfigURI
# Overload #10: repository and ConfigStream
function Set-XMLConfiguration
{
 [CmdletBinding(DefaultParametersetName='A')]
 param
 (

 )
 DynamicParam{
  Get-DynamicParamForMethod -method ([log4net.Config.XmlConfigurator]::Configure)
 }
 process
 {
  try
  {
   Invoke-MethodOverloadFromBoundParam -method ([log4net.Config.XmlConfigurator]::Configure) -Parameters $PSBoundParameters -parameterSet $PScmdlet.ParameterSetName
  }
  catch
  {
   Write-Warning "Error occured: $_"
   throw $_
  }
 }
}


#endregion

function Clear-Configuration {
 [OutputType([void])]
 Param(
		
 )
 Process {
  Try {
   if($loggers = [log4net.LogManager]::GetCurrentLoggers().logger) {
    $loggers.removeAllAPpenders()
   }
   [log4net.LogManager]::ShutdownRepository()
   [log4net.LogManager]::Shutdown()
   [log4net.LogManager]::ResetConfiguration()
  }
  Catch {
   Write-Error 'Error while trying Shutting down log4net'
  }
		
 }
}

function Reset-Configuration {
 param()
 DynamicParam {
  Get-DynamicParamForMethod -method ([log4net.LogManager]::ResetConfiguration)
 }
	
 process
 {
  try
  {
   Invoke-MethodOverloadFromBoundParam -method ([log4net.LogManager]::ResetConfiguration) -parameterSet $PSCmdlet.ParameterSetName -Parameters $PSBoundParameters
  }
  catch
  {
   Write-Warning "Error occured: $_"
   throw $_
  }
 }
}

#region FOOTER: Module configuration should be ran after all methods are defined
Receive-ModuleParameter
if($script:ParamsForSetModuleConfig.Count -gt 0) {
 Set-ModuleConfig @script:ParamsForSetModuleConfig
}
Else {
 Set-ModuleConfig
}
#endregion

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
 Clear-Configuration
 Remove-Item alias:Write-Host,alias:Write-Warning,alias:Write-Debug,alias:write-error,alias:write-verbose,alias:write-log,alias:write-information -ErrorAction SilentlyContinue
}