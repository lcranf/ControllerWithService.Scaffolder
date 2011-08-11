[T4Scaffolding.Scaffolder(Description = "Creates a set of ViewModels for a given Model")][CmdletBinding()]
param(
    
    [string]$Project,
    [string]$ModelFullName,
    [string]$ModelName,
    [string]$ModelPluralized,
    [string]$Area,
    [string]$AreaNamespace,
    [string]$DefaultNamespace,
    [string]$ModelNamespace,
    [string]$ViewModelNamespace,
    [string]$ViewModelOutputPath,
    [string]$PrimaryKey,
	[string]$CodeLanguage,
	[string[]]$TemplateFolders,
	[switch]$Force = $false
)


# If you have specified a model type
$foundModelType = Get-ProjectType $ModelName -Project $Project -BlockUi
if (!$foundModelType) 
{
   Write-Error "Model Name not found in project: $ModelName .  Please specify a ModelName!!!"  
   return
}

$namespace = (Get-Project $Project).Properties.Item("DefaultNamespace").Value
$baseViewModelNamespace = (Get-ProjectType IEditModel -Project (Get-Project *Common*).ProjectName).Namespace.Name
$defaultNamespace = $ViewModelNamespace + "." + $ModelPluralized
$baseModelFileName = "Base" + $ModelName + "Model"
$outputPath = Join-Path $viewModelOutputPath $baseModelFileName


# Create BaseEntityModel 
Add-ProjectItemViaTemplate $outputPath -Template "Model.Template" -Model @{        
        ModelType = [MarshalByRefObject]$foundModelType; 
        PrimaryKey = [string]$primaryKey; 
        DefaultNamespace = $defaultNamespace; 
        AreaNamespace = $AreaNamespace;
        ModelTypeNamespace = $modelTypeNamespace;
        ModelTypePluralized = [string]$modelTypePluralized;    
        RelatedEntities = $relatedEntities;
        ClassName = $baseModelFileName;
        IsBaseClass = $True;
        IsEditable = $True;
        IncludePrimaryKey = $True;
        SkipAllProperties = $False;
    } -SuccessMessage "Added Model {0}" -TemplateFolders $TemplateFolders -Project $Project -CodeLanguage $CodeLanguage -Force:$Force

$createModelFileName = $ModelName + "CreateModel"
$outputPath = Join-Path $viewModelOutputPath $createModelFileName 

 
# Create EntityCreateModel 
Add-ProjectItemViaTemplate $outputPath -Template "Model.Template" -Model @{        
        ModelType = [MarshalByRefObject]$foundModelType; 
        PrimaryKey = [string]$primaryKey; 
        DefaultNamespace = $defaultNamespace; 
        AreaNamespace = $AreaNamespace;
        ModelTypeNamespace = $modelTypeNamespace;
        BaseViewModelNamespace = $baseViewModelNamespace;
        ViewModelInterface = "ICreateModel";
        ModelTypePluralized = [string]$modelTypePluralized;    
        RelatedEntities = $relatedEntities;   
        ClassName = $createModelFileName;
        BaseClassName = $baseModelFileName;
        IsBaseClass = $False;
        IsEditable = $False;
        IncludePrimaryKey = $False;
        SkipAllProperties = $True;
    } -SuccessMessage "Added Model {0}" -TemplateFolders $TemplateFolders -Project $Project -CodeLanguage $CodeLanguage -Force:$Force

$editModelFileName = $ModelName + "EditModel"
$outputPath = Join-Path $viewModelOutputPath $editModelFileName


# Create EntityEditModel 
Add-ProjectItemViaTemplate $outputPath -Template "Model.Template" -Model @{        
        ModelType = [MarshalByRefObject]$foundModelType; 
        PrimaryKey = [string]$primaryKey; 
        DefaultNamespace = $defaultNamespace; 
        AreaNamespace = $AreaNamespace;
        ModelTypeNamespace = $modelTypeNamespace;
        BaseViewModelNamespace = $baseViewModelNamespace;
        ViewModelInterface = "IEditModel";
        ModelTypePluralized = [string]$modelTypePluralized;    
        RelatedEntities = $relatedEntities;
        ClassName = $editModelFileName;
        BaseClassName = $baseModelFileName;
        IsBaseClass = $False;
        IsEditable = $True;
        IncludePrimaryKey = $True;
        SkipAllProperties = $False;
    } -SuccessMessage "Added Model {0}" -TemplateFolders $TemplateFolders -Project $Project -CodeLanguage $CodeLanguage -Force:$Force   
