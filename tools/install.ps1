param($rootPath, $toolsPath, $package, $project)

# Ensure that scaffolding works
if (-not (Get-Command Invoke-Scaffolder)) { return }

# The reason is issue (http://nuget.codeplex.com/workitem/595). Now we need to remove dummy file.
if ($project) { $projectName = $project.Name }
Get-ProjectItem "NuGetDummy.txt" -Project $projectName | %{ $_.Delete() }

# TODO: modify ".cs" when decide to support VB too
# $lang = Get-ProjectLanguage
# if ($lang -eq $null) { $lang = "cs" }

Write-Host " "
Write-Host "Scaffold ControllerWithService scaffolder has been successfully installed with dependencies."
Write-Host " "
Write-Host "You can now generate Controllers with services (as opposed to repositories).  For example:"
Write-Host "PM> Scaffold ControllerWithService Order -Force -CreateVeiwModels"
Write-Host " "
Write-Host "Visit the http://https://github.com/lcranf/MyMvcSample to learn about output and conventions customization."