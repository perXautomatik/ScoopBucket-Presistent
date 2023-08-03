<#
   ========================================================================================================================
   Name         : <Name>.ps1
   Description  : This script ............................
   Created Date : %Date%
   Created By   : %UserName%
   Dependencies : 1) Windows PowerShell 5.1
                  2) .................

   Revision History
   Date       Release  Change By      Description
   %Date% 1.0      %UserName%     Initial Release
   ========================================================================================================================
#>

# Define a function to check if a .git file exists in a directory
<#
.SYNOPSIS
Checks if a .git file exists in a directory and returns true or false.

.PARAMETER Directory
The directory path to check.

.EXAMPLE
Test-GitFile -Directory "B:\PF\NoteTakingProjectFolder"

Output: True
#>
function Test-GitFile {
    param(
        # The directory path to check
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Directory
    )

    # Get the full path of the .git file in the directory
    $gitFile = Join-Path $Directory ".git"

    # Test if the .git file exists and return the result
    return Test-Path $gitFile
}

# Define a function to get the name of the work folder from a directory path
<#
.SYNOPSIS
Gets the name of the work folder from a directory path by removing the drive letter and any trailing backslashes.

.PARAMETER Directory
The directory path to get the name from.

.EXAMPLE
Get-WorkFolderName -Directory "B:\PF\NoteTakingProjectFolder"

Output: PF\NoteTakingProjectFolder
#>
function Get-WorkFolderName {
    param(
        # The directory path to get the name from
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Directory
    )

    # Remove the drive letter and any trailing backslashes from the directory path and return the result
    return $Directory.TrimStart("B:\").TrimEnd("\")
}

# Define a function to search with void tools everything for the folder name and "child:config" and get the first result
<#
.SYNOPSIS
Searches with void tools everything for the folder name and "child:config" and returns the first result as an object with properties Name, Path, and FullPath.

.PARAMETER FolderName
The folder name to search with.

.EXAMPLE
Search-Everything -FolderName "PF\NoteTakingProjectFolder"

Output: @{Name=config; Path=B:\PF\NoteTakingProjectFolder\.git\modules\NoteTakingProjectFolder; FullPath=B:\PF\NoteTakingProjectFolder\.git\modules\NoteTakingProjectFolder\config}
#>
function Search-Everything {
    param(
        # The folder name to search with
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FolderName
    )

    # Install and import the pseverything module if not already loaded
    if (-not (Get-Module -Name pseverything)) {
        Install-Module pseverything -Scope CurrentUser -Force
        Import-Module pseverything
    }

    # Use Everything to search for the folder name and "child:config" and store the results in an array variable 
    $results = Search-Everything -Filter "$FolderName child:config"

    # If there are any results, then return the first one as an object with properties Name, Path, and FullPath 
    if ($results) {
        $firstResult = $results[0]
        return [PSCustomObject]@{
            Name = $firstResult.Name
            Path = Split-Path $firstResult.FullPath -Parent
            FullPath = $firstResult.FullPath
        }
    }
}

# Define a function to overwrite git file content with "gitdir:" followed by a path
<#
.SYNOPSIS
Overwrites git file content with "gitdir:" followed by a path.

.PARAMETER GitFile
The git file path to overwrite.

.PARAMETER Path
The path to append after "gitdir:".

.EXAMPLE
Overwrite-GitFile -GitFile "B:\PF\NoteTakingProjectFolder\.git" -Path "B:\PF\NoteTakingProjectFolder\.git\modules\NoteTakingProjectFolder"

Output: The content of B:\PF\NoteTakingProjectFolder\.git is overwritten with "gitdir: B:\PF\NoteTakingProjectFolder\.git\modules\NoteTakingProjectFolder"
#>
function Overwrite-GitFile {
    param(
        # The git file path to overwrite 
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GitFile,

        # The path to append after "gitdir:"
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    # Create a new content string with "gitdir:" followed by the path 
    $newContent = "gitdir: $Path"

    # Overwrite the git file content with the new content string using Set-Content cmdlet 
    Set-Content -Path $GitFile -Value $newContent -Force
}

# Get the directory path from the user input and store it in a variable 
$directory = "B:\PF\CSharpVisualStudio\repos\8691414\WpfApp1"

# Check if a .git file exists in the directory using Test-GitFile function and store the result in a variable 
$gitFileExists = Test-GitFile -Directory $directory

# If the result is true, then proceed with the rest of the script 
if ($gitFileExists) {
    # Get the name of the work folder from the directory path using Get-WorkFolderName function and store it in a variable 
    $workFolderName = Get-WorkFolderName -Directory $directory

    # Search with void tools everything for the folder name and "child:config" and get the first result using Search-Everything function and store it in a variable 
    $firstResult = Search-Everything -FolderName $workFolderName

    # If there is a first result, then proceed with the rest of the script 
    if ($firstResult) {
        # Get the full path of the .git file in the directory and store it in a variable 
        $gitFile = Join-Path $directory ".git"

        # Get the path property of the first result and store it in a variable 
        $path = $firstResult.Path

        # Overwrite git file content with "gitdir:" followed by the path using Overwrite-GitFile function 
        Overwrite-GitFile -GitFile $gitFile -Path $path
    }
}