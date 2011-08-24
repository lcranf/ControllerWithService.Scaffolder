[T4Scaffolding.Scaffolder(Description = "Adds ASP.NET MVC views for Create/Read/Update/Delete/Index scenarios")][CmdletBinding()]
param(        
	[parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)][string]$Controller,
	[string]$ModelType,
	[string]$Area,
	[alias("MasterPage")]$Layout,	# If not set, we'll use the default layout
 	[alias("ContentPlaceholderIDs")][string[]]$SectionNames,
	[alias("PrimaryContentPlaceholderID")][string]$PrimarySectionName,
	[switch]$ReferenceScriptLibraries = $false,
    [string]$Project,
	[string]$CodeLanguage,
	[string[]]$TemplateFolders,
	[string]$ViewScaffolder = "RazorView",
    [switch]$CreateViewModels = $false,
	[switch]$Force = $false
)

@("Create", "Edit", "Delete", "Details", "Index", "_CreateOrEdit") | %{
    
    # Ensure we have a controller name, plus a model type if specified
    if ($ModelType) {
    	$foundModelType = Get-ProjectType $ModelType -Project $Project
    	if (!$foundModelType) { return }    	
    }
    
    $modelName = $foundModelType.Name
    $razorModelType = $foundModelType;
        
    if ($CreateViewModels)
    {    
        switch ($_)
        {
           "Create" {
              $viewModel = $modelName
              $viewModel+= "CreateModel"
              $razorModelType = Get-ProjectType $viewModel -Project $Project
              }      
              
             "Edit" {
              $viewModel = $modelName
              $viewModel+= "EditModel"
              $razorModelType = Get-ProjectType $viewModel -Project $Project
              }      
              
                
             "_CreateOrEdit" {
              $viewModel = "Base"
              $viewModel += $modelName
              $viewModel+= "Model"
              $razorModelType = Get-ProjectType $viewModel -Project $Project
              }         
        }
    
    }
       
	Scaffold $ViewScaffolder -Controller $Controller -ViewName $_ -ModelType $razorModelType.FullName -EntityModelType $foundModelType.FullName -Template $_ -Area $Area -Layout $Layout -SectionNames $SectionNames -PrimarySectionName $PrimarySectionName -ReferenceScriptLibraries:$ReferenceScriptLibraries -Project $Project -CodeLanguage $CodeLanguage -OverrideTemplateFolders $TemplateFolders -Force:$Force -BlockUi -CreateViewModels:$CreateViewModels
}