[T4Scaffolding.Scaffolder(Description = "Creates a DbContext, DbContextRegistry and DbContextInitializer classes")][CmdletBinding()]
param(
	[parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$DbContextType,
	[string]$Area,
    [string]$Project,
	[string]$CodeLanguage,
	[string[]]$TemplateFolders
)


# Find the DbContext class, or create it via a template if not already present
$foundDbContextType = Get-ProjectType $DbContextType -Project $Project -AllowMultiple
$dbContextNamespace = ""
$defaultNamespace = (Get-Project $Project).Properties.Item("DefaultNamespace").Value

if (!$foundDbContextType) {
	# Determine where the DbContext class will go	
	if ($DbContextType.Contains(".")) {
		if ($DbContextType.StartsWith($defaultNamespace + ".", [System.StringComparison]::OrdinalIgnoreCase)) {
			$DbContextType = $DbContextType.Substring($defaultNamespace.Length + 1)
		}
		$outputPath = $DbContextType.Replace(".", [System.IO.Path]::DirectorySeparatorChar)
		$DbContextType = [System.IO.Path]::GetFileName($outputPath)
	} else {
		$outputPath = Join-Path Models $DbContextType
		if ($Area) {
			$areaFolder = Join-Path Areas $Area
			if (-not (Get-ProjectItem $areaFolder -Project $Project)) {
				Write-Error "Cannot find area '$Area'. Make sure it exists already."
				return
			}
			$outputPath = Join-Path $areaFolder $outputPath
		}
	}
	
	$dbContextNamespace = [T4Scaffolding.Namespaces]::Normalize($defaultNamespace + "." + [System.IO.Path]::GetDirectoryName($outputPath).Replace([System.IO.Path]::DirectorySeparatorChar, "."))
    # 1.  Create Custom Db Context
	Add-ProjectItemViaTemplate $outputPath -Template CustomDbContext -Model @{
		DefaultNamespace = $defaultNamespace; 
		DbContextNamespace = $dbContextNamespace; 
		DbContextType = $DbContextType; 
	} -SuccessMessage "Added database context '{0}'" -TemplateFolders $TemplateFolders -Project $Project -CodeLanguage $CodeLanguage -Force:$Force	
} elseif (($foundDbContextType | Measure-Object).Count -gt 1) {
	throw "Cannot find the database context class, because more than one type is called $DbContextType. Try specifying the fully-qualified type name, including namespace."
}


$dbRegistryName = $DbContextType + "Registry"
$dbRegistryOutputPath = Join-Path Models $dbRegistryName

# 2. Create DbContextRegistry
Add-ProjectItemViaTemplate $dbRegistryOutputPath -Template CustomDbContextRegistry -Model @{
   DbRegistryName = $dbRegistryName;
   DbContextType = $DbContextType;
   DbContextNamespace = $dbContextNamespace;
} -SuccessMessage "Added db registry '{0}'" -TemplateFolders $TemplateFolders -Project $Project -CodeLanguage $CodeLanguage -Force:$Force

$dbContextInitializer = $DbContextType + "Initializer"
$dbContextOutputPath = Join-Path Models $dbContextInitializer

# 3. Create DbContextInitializer
Add-ProjectItemViaTemplate $dbContextOutputPath -Template CustomDbContextInitializer -Model @{
   DbInitializerName = $dbContextInitializer;
   DbContextType = $DbContextType;
   DbContextNamespace = $dbContextNamespace;
} -SuccessMessage "Added db registry '{0}'" -TemplateFolders $TemplateFolders -Project $Project -CodeLanguage $CodeLanguage -Force:$Force


# 4.  Add NinjectRegistration file
Add-ProjectItemViaTemplate "NinjectRegistration" -Template NinjectRegistration -Model @{
   DefaultNamespace = $defaultNamespace;
   DbContextNamespace = $dbContextNamespace;
   DbContextType = $DbContextType;
   DbRegistryName = $dbRegistryName;
} -SuccessMessage "Added Ninject Registration '{0}'" -TemplateFolders $TemplateFolders -Project $Project -CodeLanguage $CodeLanguage -Force:$Force

return @{
	DbContextType = $foundDbContextType
}