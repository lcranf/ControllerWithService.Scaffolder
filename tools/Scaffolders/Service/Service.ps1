[T4Scaffolding.Scaffolder(Description = "Create Crud Services for the specified Entity")][CmdletBinding()]
param(        
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$ModelName,
    [string]$Project,    
    [string]$ServiceProject,    
    [string]$EntityNamespace,    
    [string]$OutputPath = "Services",
    [string]$DbContextType,
    [string]$DbContextTypeNamespace,
    [string]$DefaultNamespace,
	[string]$CodeLanguage,
	[string[]]$TemplateFolders,
    [switch]$NoIoc = $false,
	[switch]$Force = $false
)

# If you have specified a model type
$foundModelType = Get-ProjectType $ModelName -Project $Project -BlockUi
$modelTypeNamespace = $EntityNamespace

if (!$foundModelType) 
{
   Write-Error "Model Name not found in project: $ModelName .  Please specify a ModelName!!!"  
   return
}
else {
   if (!$entityNamespace) {
      Write-Warning "No Namespace provided for Entity.  Defaulting to Model Type" 
      $modelTypeNamespace = $foundModelType.Namespace.Name
   }
}


if (!$DefaultNamespace) {
   Write-Warning "No Default Namespace provided.  Defaulting Services namespace"
   $namespace = $Project + "." + $OutputPath
}
else {
   $namespace = $DefaultNamespace
}


# If ServiceProject is omitted, then fallback to the default project provided by the NuGet Manager
if(!$ServiceProject) {
   $ServiceProject = $Project
} else {  
  $namespace = $ServiceProject + "." + $OutputPath  
}

# Try and find base IRepository file.  NOTE:  As of now an error is thrown if IRepository is not found
$baseRepositoryNamespace = "EF.CodeFirst.Common.Repository"
$baseServiceNamespace = "EF.CodeFirst.Common.Service"
$dbContextType = $DbContextType
$dbContextTypeNamespace = $DbContextTypeNamespace

$serviceInterface = "I" + $ModelName + "Service"
$interfaceOutputPath = Join-Path $OutputPath $serviceInterface


# If NoIoc switch is supplied then make sure DbContext is supplied
if($NoIoc.IsPresent -and !$dbContextType) {
    $dbContextName = [System.Text.RegularExpressions.Regex]::Replace((Get-Project $Project).Name, "[^a-zA-Z0-9]", "") + "Context"
    $dbContext = Get-ProjectType $dbContextName -Project $Project
    $dbContextType = $dbContext.Name
    $dbContextTypeNamespace = $dbContext.Namespace.Name    
}

Add-ProjectItemViaTemplate $interfaceOutputPath -Template IService -Model @{
     Namespace = $namespace;
     ModelType = [MarshalByRefObject]$foundModelType; 
     PrimaryKey = [string]$primaryKey; 
     DefaultNamespace = $defaultNamespace; 
     AreaNamespace = $areaNamespace;
     ModelTypeNamespace = $modelTypeNamespace;     
     ServiceNamespace = $baseServiceNamespace;
     DbContextType = $dbContextType;
     DbContextNamespace = $dbContextTypeNamespace;
     NoIoc = $NoIoc.IsPresent;
  } -SuccessMessage "Added Service output at {0}" `
	-TemplateFolders $TemplateFolders -Project $ServiceProject -CodeLanguage $CodeLanguage -Force:$Force

$serviceImplementation = $ModelName + "Service"
$implementationOutputPath = Join-Path $OutputPath $serviceImplementation

Add-ProjectItemViaTemplate $implementationOutputPath -Template Service -Model @{
     Namespace = $namespace;
     ModelType = [MarshalByRefObject]$foundModelType; 
     PrimaryKey = [string]$primaryKey; 
     DefaultNamespace = $defaultNamespace; 
     AreaNamespace = $areaNamespace;
     ModelTypeNamespace = $modelTypeNamespace;
     RepositoryNamespace = $baseRepositoryNamespace;
     ServiceNamespace = $baseServiceNamespace;
     DbContextType = $dbContextType;
     DbContextNamespace = $dbContextTypeNamespace;
     NoIoc = $NoIoc.IsPresent;
  } -SuccessMessage "Added Service output at {0}" `
	-TemplateFolders $TemplateFolders -Project $ServiceProject -CodeLanguage $CodeLanguage -Force:$Force