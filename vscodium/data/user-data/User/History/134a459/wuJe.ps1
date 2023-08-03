
# \fix-CorruptedGitModules.ps1
<#
This code is a PowerShell script that checks the status of git repositories in a given folder and repairs 
them if they are corrupted. It does the following steps:

It defines a begin block that runs once before processing any input. In this block, it sets some variables
 for the modules and folder paths, validates them, and redirects the standard error output of git commands
  to the standard output stream.
It defines a process block that runs for each input object. In this block, it loops through each subfolder
 in the folder path and runs git status on it. If the output is fatal, it means the repository is corrupted 
 and needs to be repaired. To do that, it moves the corresponding module folder from the modules path to the
  subfolder, replacing the existing .git file or folder. Then, it reads the config file of the repository and
   removes any line that contains worktree, which is a setting that can cause problems with scoop. It prints 
   the output of each step to the console.
It defines an end block that runs once after processing all input. In this block, it restores the original
 location of the script.#>



 . $PSScriptRoot\Invoke-Git.ps1
 . $PSScriptRoot\Split-TextByRegex.ps1
 . $PSScriptRoot\git-GetSubmodulePathsUrls.ps1
 . $PSScriptRoot\config-to-gitmodules.ps1
 

# \fix-CorruptedGitModulesCombinedWithQue.ps1

function Validate-Path {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    if (-not (Test-Path $Path)) {
        Write-Error "Invalid path: $Path"
        exit 1
    }
}


# \GetWorktreeSubmodules.ps1

    # Define a function to convert key-value pairs to custom objects

# Define a function to get the URL of a submodule
function byPath-RepoUrl {
    param(
        [string]$Path # The path of the submodule directory
    )
    # Change the current location to the submodule directory
    Push-Location -Path $Path -ErrorAction Stop
    # Get the URL of the origin remote
    $url = invoke-git "config remote.origin.url" -ErrorAction Stop
    # Parse the URL to get the part after the colon
    $parsedUrl = ($url -split ':')[1]
    # Return to the previous location
    Pop-Location -ErrorAction Stop
    # Return the parsed URL as output
    return $parsedUrl
}



function get-gitUnhide ($Path)
{
    Get-ChildItem -Path "$Path\*" -Force | Where-Object { $_.Name -eq ".git" }
}



# requries gitmodulesfile


# \GitSyncSubmoduleWithConfig.ps1
<#
.SYNOPSIS
Synchronizes the submodules with the config file.

.DESCRIPTION
This function synchronizes the submodules with the config file, using the Git-helper and ini-helper modules. The function checks the remote URLs of the submodules and updates them if they are empty or local paths. The function also handles conflicts and errors.

.PARAMETER GitDirPath
The path of the git directory where the config file is located.

.PARAMETER GitRootPath
The path of the git root directory where the submodules are located.

.PARAMETER FlagConfigDecides
A switch parameter that indicates whether to use the config file as the source of truth in case of conflicting URLs.
#>

# A function to move a .git Folder into the current directory and remove any gitfiles present
function unearthiffind ()
{
    param (
        [Parameter(Mandatory=$true)]
        [string]$toRepair,
        [Parameter(Mandatory=$true)]
        [string]$Modules
    )
        # Get the module folder that matches the name of the parent directory
        Get-ChildItem -Path $Modules -Directory | Where-Object { $_.Name -eq $toRepair.Directory.Name } | Select-Object -First 1 | % {

        # Move the module folder to replace the .git file
        Remove-Item -Path $toRepair -Force 
        Move-Item -Path $_.FullName -Destination $toRepair -Force 
    }
}


# A function to check the git status of a folder
function Check-GitStatus ($folder) {
    # Change the current directory to the folder
    Set-Location $folder.FullName
    Write-Output "checking $folder"
    if ((Get-ChildItem -force | ?{ $_.name -eq ".git" } ))
    {
      # Run git status and capture the output
      $output = Invoke-Git "git status"
      
      if(($output -like "fatal*"))
      { 
        Write-Output "fatal status for $folder"
        #UnabosrbeOrRmWorktree $folder
      }
      else
      {
        Write-Output @($output)[0]
      }
    }
    else
    {
      Write-Output "$folder not yet initialized"
    }
  }
  
 # Define a function to remove the worktree from a config file
 function Remove-Worktree {
    param(
        [string]$ConfigPath # The path of the config file
    )
    if(Test-Package "Get-IniContent")
    {
        # Get the content of the config file as an ini object
        $iniContent = Get-IniContent -FilePath $ConfigPath
        # Remove the worktree property from the core section
        $iniContent.core.Remove("worktree")
        # Write the ini object back to the config file
        $iniContent | Out-IniFile -FilePath $ConfigPath -Force  
    }
    else
    {
        # Read the config file content as an array of lines
        $configLines = Get-Content -Path $ConfigPath

        # Filter out the lines that contain worktree
        $newConfigLines = $configLines | Where-Object { $_ -notmatch "worktree" }

        if (($configLines | Where-Object { $_ -match "worktree" }))
        {
            # Write the new config file content
            Set-Content -Path $ConfigPath -Value $newConfigLines -Force
        }
    }
}


function Remove-WorktreeHere {
    param(
        [string]$ConfigPath, # The path of the config file
        [alias]$folder,$toRepair
    )

    # Get the path to the git config file
    $configFile = Join-Path -Path $toRepair -ChildPath "\config"
    
    # Check if it exists
    if (-not (Test-Path $configFile)) {
        Write-Error "Invalid folder path: $toRepair"  
    }
    else
    {
        Remove-Worktree -ConfigPath $toRepair
    }

}
  
# A function to repair a corrupted git folder
# param folder: where to look for replacement module to unearth with
function UnabosrbeOrRmWorktree ($folder) {

    get-gitUnhide $folder | % {
        if( $_ -is [System.IO.FileInfo] )
        {
            unearthIffind $_ $folder
        }
        elseif( $_ -is [System.IO.DirectoryInfo] )
        {
            Remove-WorktreeHere $_
        }
        else
        {
            Write-Error "not a .git file or folder: $_"
        }
  }
}

# A function to repair a fatal git status
function UnabosrbeOrRmWorktree {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$Modules
    )
    # Print a message indicating fatal status
    write-verbos "fatal status for $Path, atempting repair"

    cd $Path
    UnabosrbeOrRmWorktree -folder $Modules
    
}


function RepairWithQue-N-RepairFolder {
        
    # Synopsis: A script to process files with git status and repair them if needed
    # Parameter: Start - The start path to process
    # Parameter: Modules - The path to the modules folder
    param (
        [Parameter(Mandatory=$true)]
        [string]$Start,
        [Parameter(Mandatory=$true)]
        [string]$Modules
    )
    
    begin {
        
        Push-Location

        # Validate the arguments
        Validate-Path -Path $Start
        Validate-Path -Path $Modules

        # Redirect the standard error output of git commands to the standard output stream
        $env:GIT_REDIRECT_STDERR = '2>&1'

        Write-Progress -Activity "Processing files" -Status "Starting" -PercentComplete 0

        # Create a queue to store the paths
        $que = New-Object System.Collections.Queue

        # Enqueue the start path
        $Start | % { $que.Enqueue($_) }

        # Initialize a counter variable
        $i = 0;
        
    }
    
    process {

         # Loop through the queue until it is empty
         do
         {    
             # Increment the counter
             $i++;

             # Dequeue a path from the queue
             $path = $que.Dequeue()

             # Change the current directory to the path
             Set-Location $path;

             # Run git status and capture the output
             $output = Check-GitStatus $path

             # Check if the output is fatal
             if($output -like "fatal*")
             {
                 ActOnError  -Path $path -Modules $modules                  
                
                 # Get the subdirectories of the path and enqueue them, excluding any .git folders
                 if ($continueOnError)
                 {
                     $toEnque = Get-ChildItem -Path "$path\*" -Directory -Exclude "*.git*" 
                 }
             }
             else
             {
                $toEnque = git-GetSubmodulePathsUrls
             }
            $toEnque | % { $que.Enqueue($_.FullName) }

             # Calculate the percentage of directories processed
             $percentComplete =  ($i / ($que.count+$i) ) * 100

             # Update the progress bar
             Write-Progress -Activity "Processing files" -PercentComplete $percentComplete

         } while ($que.Count -gt 0)
    }
    
    end {
        # Restore the original location
        Pop-Location
        Write-Progress -Activity "Processing files" -Status "Finished" -PercentComplete 100
    }
}
