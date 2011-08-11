[T4Scaffolding.ControllerScaffolder("Controller with read/write action and views, using EF data access code", Description = "Adds an ASP.NET MVC controller with views and data access code", SupportsModelType = $true, SupportsDataContextType = $true, SupportsViewScaffolder = $true)][CmdletBinding()]
param(     
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$ControllerName,   
    [string]$ModelType,
    [string]$Project,
    [string]$CodeLanguage,
    [string]$DbContextType,
    [string]$Area,
    [string]$ViewScaffolder = "RazorView",
    [alias("MasterPage")]$Layout,
    [alias("ContentPlaceholderIDs")][string[]]$SectionNames,
    [alias("PrimaryContentPlaceholderID")][string]$PrimarySectionName,    
    [switch]$ReferenceScriptLibraries = $false,
    [switch]$NoIoc = $false,    
    [switch]$NoChildItems = $false,    
    [string[]]$TemplateFolders,
    [switch]$CreateViewModels = $false,
    [switch]$Force = $false,
    [string]$ForceMode
)

if (!((Get-ProjectAspNetMvcVersion -Project $Project) -ge 3)) {
    Write-Error ("Project '$((Get-Project $Project).Name)' is not an ASP.NET MVC 3 project.")
    return
}

# Interpret the "Force" and "ForceMode" options
$overwriteController = $Force -and ((!$ForceMode) -or ($ForceMode -eq "ControllerOnly"))
$overwriteFilesExceptController = $Force -and ((!$ForceMode) -or ($ForceMode -eq "PreserveController"))

# Ensure you've referenced System.Data.Entity
(Get-Project $Project).Object.References.Add("System.Data.Entity") | Out-Null

# If you haven't specified a model type, we'll guess from the controller name
if (!$ModelType) {
    if ($ControllerName.EndsWith("Controller", [StringComparison]::OrdinalIgnoreCase)) {
        # If you've given "PeopleController" as the full controller name, we're looking for a model called People or Person
        $ModelType = [System.Text.RegularExpressions.Regex]::Replace($ControllerName, "Controller$", "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $foundModelType = Get-ProjectType $ModelType -Project $Project -BlockUi -ErrorAction SilentlyContinue
        if (!$foundModelType) {
            $ModelType = [string](Get-SingularizedWord $ModelType)
            $foundModelType = Get-ProjectType $ModelType -Project $Project -BlockUi -ErrorAction SilentlyContinue
        }
    } else {
        # If you've given "people" as the controller name, we're looking for a model called People or Person, and the controller will be PeopleController
        $ModelType = $ControllerName
        $foundModelType = Get-ProjectType $ModelType -Project $Project -BlockUi -ErrorAction SilentlyContinue
        if (!$foundModelType) {
            $ModelType = [string](Get-SingularizedWord $ModelType)
            $foundModelType = Get-ProjectType $ModelType -Project $Project -BlockUi -ErrorAction SilentlyContinue
        }
        if ($foundModelType) {
            $ControllerName = [string](Get-PluralizedWord $foundModelType.Name) + "Controller"
        }
    }
    if (!$foundModelType) { throw "Cannot find a model type corresponding to a controller called '$ControllerName'. Try supplying a -ModelType parameter value." }
} else {
    # If you have specified a model type
    $foundModelType = Get-ProjectType $ModelType -Project $Project -BlockUi
    if (!$foundModelType) { return }
    if (!$ControllerName.EndsWith("Controller", [StringComparison]::OrdinalIgnoreCase)) {
        $ControllerName = $ControllerName + "Controller"
    }
}
Write-Host "Scaffolding $ControllerName..."

if(!$DbContextType) { $DbContextType = [System.Text.RegularExpressions.Regex]::Replace((Get-Project $Project).Name, "[^a-zA-Z0-9]", "") + "Context" }
if (!$NoChildItems) {    
        $dbContextScaffolderResult = Scaffold DbContext -ModelType $foundModelType.FullName -DbContextType $DbContextType -Area $Area -Project $Project -CodeLanguage $CodeLanguage -BlockUi
        $foundDbContextType = $dbContextScaffolderResult.DbContextType
        if (!$foundDbContextType) { return }    
}
if (!$foundDbContextType) { $foundDbContextType = Get-ProjectType $DbContextType -Project $Project }
if (!$foundDbContextType) { return }

$primaryKey = Get-PrimaryKey $foundModelType.FullName -Project $Project -ErrorIfNotFound
if (!$primaryKey) { return }

$outputPath = Join-Path Controllers $ControllerName

# We don't create areas here, so just ensure that if you specify one, it already exists
if ($Area) {
    $areaPath = Join-Path Areas $Area
    if (-not (Get-ProjectItem $areaPath -Project $Project)) {
        Write-Error "Cannot find area '$Area'. Make sure it exists already."
        return
    }
    $outputPath = Join-Path $areaPath $outputPath
}

# Prepare all the parameter values to pass to the template, then invoke the template with those values
$defaultNamespace = (Get-Project $Project).Properties.Item("DefaultNamespace").Value
$modelTypeNamespace = [T4Scaffolding.Namespaces]::GetNamespace($foundModelType.FullName)
$controllerNamespace = [T4Scaffolding.Namespaces]::Normalize($defaultNamespace + "." + [System.IO.Path]::GetDirectoryName($outputPath).Replace([System.IO.Path]::DirectorySeparatorChar, "."))
$areaNamespace = if ($Area) { [T4Scaffolding.Namespaces]::Normalize($defaultNamespace + ".Areas.$Area") } else { $defaultNamespace }
$dbContextNamespace = $foundDbContextType.Namespace.FullName
$repositoriesNamespace = [T4Scaffolding.Namespaces]::Normalize($areaNamespace + ".Models")
$viewModelsNamespace = [T4Scaffolding.Namespaces]::Normalize($areaNamespace + ".ViewModels")
$modelTypePluralized = Get-PluralizedWord $foundModelType.Name
$viewModelsPath = Join-Path ViewModels $modelTypePluralized
$relatedEntities = [Array](Get-RelatedEntities $foundModelType.FullName -Project $project)
if (!$relatedEntities) { $relatedEntities = @() }

$serviceProject = (Get-Project *Core*).ProjectName

if(!$serviceProject) {
   Write-Warning "No Service Project found.  Falling back to default project"
   $serviceProject = $Project
}

Scaffold Service -ModelName $foundModelType.Name -DefaultNamespace $defaultNamespace `
                 -Project $Project -ServiceProject $serviceProject -CodeLanguage $CodeLanguage `
                 -NoIoc:$NoIoc `
                 -EntityNamespace $modelTypeNamespace -Force:$overwriteFilesExceptController

$serviceName = $foundModelType.Name + "Service"
$ServiceNamespace = (Get-ProjectType $serviceName -Project (Get-Project $serviceProject).ProjectName).Namespace.Name
$baseControllerNamespace = (Get-ProjectType "BaseController" -Project (Get-Project "*Common*").ProjectName).Namespace.Name
$commonExtensionNamespace = (Get-ProjectType "MapEntityToModelExtensions" -Project (Get-Project "*Common*").ProjectName).Namespace.Name


# Add Controller

Add-ProjectItemViaTemplate $outputPath -Template "ControllerWithService" -Model @{
    ControllerName = $ControllerName;
    ModelType = [MarshalByRefObject]$foundModelType; 
    PrimaryKey = [string]$primaryKey; 
    DefaultNamespace = $defaultNamespace; 
    AreaNamespace = $areaNamespace; 
    DbContextNamespace = $dbContextNamespace;
    RepositoriesNamespace = $repositoriesNamespace;
    ServiceNamespace = $ServiceNamespace;
    ModelTypeNamespace = $modelTypeNamespace; 
    ControllerNamespace = $controllerNamespace;
    BaseControllerNamespace = $baseControllerNamespace;
    ViewModelNamespace = $viewModelsNamespace;
    CommonExtensionNamespace = $commonExtensionNamespace;
    DbContextType = [MarshalByRefObject]$foundDbContextType;    
    ModelTypePluralized = [string]$modelTypePluralized;    
    RelatedEntities = $relatedEntities;
    CreateViewModels = $CreateViewModels.IsPresent;
    NoIoc = $NoIoc.IsPresent;
} -SuccessMessage "Added controller {0}" -TemplateFolders $TemplateFolders -Project $Project -CodeLanguage $CodeLanguage -Force:$overwriteController


if($CreateViewModels) {
       Scaffold ViewModels -ModelFullName $foundModelType.FullName `
       -ModelName $foundModelType.Name -ModelPluralized $modelTypePluralized `
       -Area $Area -AreaNamespace $areaNamespace -ModelNamespace $modelTypeNamespace `
       -ViewModelNamespace $viewModelsNamespace -PrimaryKey = $primaryKey `
       -ViewModelOutputPath $viewModelsPath -DefaultNamespace $defaultNamespace `
       -Project $Project -CodeLanguage $CodeLanguage -Force:$overwriteFilesExceptController       
}

if (!$NoChildItems) {
    $controllerNameWithoutSuffix = [System.Text.RegularExpressions.Regex]::Replace($ControllerName, "Controller$", "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($ViewScaffolder) {
        Scaffold RazorViews -ViewScaffolder $ViewScaffolder -Controller $controllerNameWithoutSuffix `
                       -ModelType $foundModelType.FullName -Area $Area -Layout $Layout `
                       -SectionNames $SectionNames -PrimarySectionName $PrimarySectionName `
                       -ReferenceScriptLibraries:$ReferenceScriptLibraries -Project $Project `
                       -CodeLanguage $CodeLanguage -CreateViewModels:$CreateViewModels -Force:$overwriteFilesExceptController
    }
}