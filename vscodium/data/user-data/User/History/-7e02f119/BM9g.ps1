



    # A function to run git commands and check the exit code
    function Invoke-Git {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command # The git command to run
    )
    # Run the command and capture the output
    $output = Invoke-Expression -Command "git $Command" -ErrorAction Stop
    # return the output to the host
    $output
    # Check the exit code and throw an exception if not zero
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $Command"
    }
    }


# \fix-CorruptedGitModulesCombinedWithQue.ps1
# A function to validate a path argument
function Validate-Path {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    if (-not (Test-Path $Path)) {
        Write-Error "Invalid $Name path: $Path"
        exit 1
    }
}
    # Define a function to split text by a regular expression
  # Define a function to split text by a regular expression
  function Split-TextByRegex {
    <#
    .SYNOPSIS
    Splits text by a regular expression and returns an array of objects with the start index, end index, and value of each match.

    .DESCRIPTION
    This function takes a path to a text file and a regular expression as parameters, and returns an array of objects with the start index, end index, and value of each match. The function uses the Select-String cmdlet to find the matches, and then creates custom objects with the properties of each match.

    .PARAMETER Path
    The path to the text file to be split.

    .PARAMETER Regx
    The regular expression to use for splitting.

    .EXAMPLE
    Split-TextByRegex -Path ".\test.txt" -Regx "submodule"

    This example splits the text in the test.txt file by the word "submodule" and returns an array of objects with the start index, end index, and value of each match.
    #>

    # Validate the parameters
    [CmdletBinding()]
    param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string]$Path,
    [Parameter(Mandatory=$true)]
    [string]$Regx
    )

        # Try to read the text from the file
    try {
        $Content = Get-Content $Path -Raw
    }
    catch {
            Write-Error "Could not read the file: $_"
        return
    }

    # Try to split the content by the regular expression
    try {
        $Matchez = [regex]::Matches($Content, $Regx)
        $NonMatches = [regex]::Split($Content, $Regx)        
        $single = Select-String -InputObject $Content -Pattern $Regx -AllMatches | Select-Object -ExpandProperty Matches
    }
    catch {
        Write-Error "Could not split the content by $Regx"
        return
    }

        # Create an array to store the results
    $Results = @()

    if($IncNonmatches)
    {
        # Loop through the matches and non-matches and create custom objects with the index and value properties
        for ($i = 0; $i -lt $Matchez.Count; $i++) {
            $Results += [PSCustomObject]@{
                index = $Matchez[$i].Index
                value = $Matchez[$i].Value
            }
            $Results += [PSCustomObject]@{
                index = $Matchez[$i].Index + $Matches[$i].Length
                value = $NonMatches[$i + 1]
            }
        }
    }        
    else {    
            # Loop through each match and create a custom object with its properties
        foreach ($match in $single) {
            $result = [PSCustomObject]@{
                StartIndex = $match.Index
                EndIndex = $match.Index + $match.Length - 1
                Value = $match.Value
            }
            # Add the result to the array
            $results += $result
        }
    }

    # Return the results
    return $Results

}


# Define a function to get the URL of a submodule
function byPath-RepoUrl {
    param(
        [string]$Path # The path of the submodule directory
    )
    # Change the current location to the submodule directory
    Push-Location -Path $Path -ErrorAction Stop
    # Get the URL of the origin remote
    $url = git config remote.origin.url -ErrorAction Stop
    # Parse the URL to get the part after the colon
    $parsedUrl = ($url -split ':')[1]
    # Return to the previous location
    Pop-Location -ErrorAction Stop
    # Return the parsed URL as output
    return $parsedUrl
}



function git-GetSubmodulePathsUrls
{    [CmdletBinding()]
        Param(       
            [Parameter(Mandatory=$true)]
            [ValidateScript({Test-Path -Path "$_\.gitmodules"})]            
            [string]
            $RepoPath
        )
        try {    
            (git config -f .gitmodules --get-regexp '^submodule\..*\.path$')  | 
            % {
                $path_key, $path = $_.split(" ")
                $prop = [ordered]@{ 
                    Path = $path
                    Url = git config -f .gitmodules --get ("$path_key" -replace "\.path",".url")
                    NonRelative = Join-Path $RepoPath $path
                }
                return New-Object –TypeName PSObject -Property $prop
            }        
        }
        catch{
            Throw "$($_.Exception.Message)"
        }
}


Function Git-InitializeSubmodules {
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
       Param(
        # File to Create
        [Parameter(Mandatory=$true)]
        [string]
        $RepoPath
    )
    begin{    
    	Write-Verbose "[Add Git Submodule from .gitmodules]"    
    }
    process{
    
        git-GetSubmodulePathsUrls $RepoPath | %{   $url = $_.url
            $path = $_.path
            
            if( New-Item -ItemType dir -Name $path -WhatIf -ErrorAction SilentlyContinue)
            {
                if($PSCmdlet.ShouldProcess($path,"clone $url -->")){                                                   
                 
                }
                else
                {
                   git submodule add $url $path
                }
            }
            else
            {
                if($PSCmdlet.ShouldProcess($path,"folder already exsists, will trye to clone $url --> "))
                {   
                    
                }
                else
                {
                  git submodule add $url $path
                }
            }
        }
    }
}





    # A function to get the submodules recursively for a given repo path
    function Get-SubmodulesRecursive {
        param(
            [Parameter(Mandatory=$true)]
            [string]$RepoPath # The path to the repo
        )
    
        begin {
            # Validate the repo path
            Validate-Path -Path $RepoPath -Name "repo"
    
            # Change the current directory to the repo path
            Set-Location $RepoPath
    
            # Initialize an empty array for the result
            $result = @()
        }
    
        process {
            # Run git submodule foreach and capture the output as an array of lines
            $list = @(Invoke-Git "submodule foreach --recursive 'git rev-parse --git-dir'")
    
            # Loop through the list and skip the last line (which is "Entering '...'")
            foreach ($i in 0.. ($list.count-2)) { 
            # Check if the index is even, which means it is a relative path line
            if ($i % 2 -eq 0) 
            {
                # Create a custom object with the base, relative and gitDir properties and add it to the result array
                $result += , [PSCustomObject]@{
                base = $RepoPath
                relative = $list[$i]
                gitDir = $list[$i+1]
                }
            }
            }
            
        }
    
        end {
            # Return the result array
            $result 
        }
        }
    
    


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

# A function to validate the arguments
function Validate-Arguments ($modules, $folder) {
  if (-not (Test-Path $modules)) { 
    Write-Error "Invalid modules path: $modules"
    exit 1
  }

  if (-not (Test-Path $folder)) {
    Write-Error "Invalid folder path: $folder"
    exit 1
  }
}

# A function to repair a corrupted git folder
function Repair-GitFolder ($folder) {
  $folder | Get-ChildItem -force | ?{ $_.name -eq ".git" } | % {
    $toRepair = $_

    if( $toRepair -is [System.IO.FileInfo] )
    {
      Move-GitFile $toRepair
    }
    elseif( $toRepair -is [System.IO.DirectoryInfo] )
    {
      Fix-GitConfig $toRepair
    }
    else
    {
      Write-Error "not a .git file or folder: $toRepair"
    }
  }
}

# A function to move a .git file to the corresponding module folder
function Move-GitFile ($file) {
  global:$modules | Get-ChildItem -Directory | ?{ $_.name -eq $file.Directory.Name } | select -First 1 | % {
    # Move the folder to the target folder
    rm $file -force ; Move-Item -Path $_.fullname -Destination $file -force 
  }
}

# A function to fix the worktree setting in a .git config file
function Fix-GitConfig ($folder) {
  # Get the path to the git config file
  $configFile = Join-Path -Path $folder -ChildPath "\config"

  if (-not (Test-Path $configFile)) {
    Write-Error "Invalid folder path: $folder"  
  }
  else
  {
    # Read the config file content as an array of lines
    $configLines = Get-Content -Path $configFile

    # Filter out the lines that contain worktree
    $newConfigLines = $configLines | Where-Object { $_ -notmatch "worktree" }

    if (($configLines | Where-Object { $_ -match "worktree" }))
    {
      # Write the new config file content
      Set-Content -Path $configFile -Value $newConfigLines -Force
    }
  }
}


# A function to repair a fatal git status
function Repair-Git {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$Modules
    )
    # Print a message indicating fatal status
    Write-Output "fatal status for $Path"

    # Get the .git file or folder in that path
    $toRepair = Get-ChildItem -Path "$Path\*" -Force | Where-Object { $_.Name -eq ".git" }

    # Check if it is a file or a folder
    if( $toRepair -is [System.IO.FileInfo] )
    {
        # Get the module folder that matches the name of the parent directory
        $module = Get-ChildItem -Path $Modules -Directory | Where-Object { $_.Name -eq $toRepair.Directory.Name } | Select-Object -First 1

        # Move the module folder to replace the .git file
        Remove-Item -Path $toRepair -Force 
        Move-Item -Path $module.FullName -Destination $toRepair -Force 
    }
    elseif( $toRepair -is [System.IO.DirectoryInfo] )
    {
        # Get the path to the git config file
        $configFile = Join-Path -Path $toRepair -ChildPath "\config"

        # Check if it exists
        if (-not (Test-Path $configFile)) {
          Write-Error "Invalid folder path: $toRepair"  
        }
        else
        {
            # Read the config file content as an array of lines
            $configLines = Get-Content -Path $configFile

            # Filter out the lines that contain worktree
            $newConfigLines = $configLines | Where-Object { $_ -notmatch "worktree" }

            # Check if there are any lines to remove
            if (($configLines | Where-Object { $_ -match "worktree" }))
            {
                # Write the new config file content
                Set-Content -Path $configFile -Value $newConfigLines -Force
            }
        }
    }
    else
    {
        # Print an error message if it is not a file or a folder
        Write-Error "not a .git file or folder: $toRepair"
    }
}

# A function to process files with git status and repair them if needed
function Process-Files {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Start,
        [Parameter(Mandatory=$true)]
        [string]$Modules
    )
    
    begin {
        
        Push-Location

        # Validate the arguments
        Validate-Path -Path $Start -Name "start"
        Validate-Path -Path $Modules -Name "modules"

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
             $output = git status

             # Check if the output is fatal
             if($output -like "fatal*")
             {
                 Repair-Git -Path $path -Modules $modules 
             }
             else
             {
                 # Get the subdirectories of the path and enqueue them, excluding any .git folders
                 Get-ChildItem -Path "$path\*" -Directory -Exclude "*.git*" | % { $que.Enqueue($_.FullName) }
             }

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

    # Define a function to convert key-value pairs to custom objects
    function keyPairTo-PsCustom {
        <#
        .SYNOPSIS
        Converts key-value pairs to custom objects with properties corresponding to the keys and values.

        .DESCRIPTION
        This function takes an array of strings containing key-value pairs as a parameter, and returns an array of custom objects with properties corresponding to the keys and values. The function uses the ConvertFrom-StringData cmdlet to parse the key-value pairs, and then creates custom objects with the properties.

        .PARAMETER KeyPairStrings
        The array of strings containing key-value pairs.

        .EXAMPLE
        keyPairTo-PsCustom -KeyPairStrings @("name=John", "age=25")

        This example converts the key-value pairs in the array to custom objects with properties name and age.
        
        #>

        # Validate the parameter
        [CmdletBinding()]
        param (
            [Parameter(Mandatory=$true)]
            [string[]]$KeyPairStrings
        )

        # Create an array to store the results
        $results = @()

        # Loop through each string in the array
        foreach ($string in $KeyPairStrings) {
            # Try to parse the key-value pairs using ConvertFrom-StringData cmdlet
            try {
                $data = ConvertFrom-StringData $string
            }
            catch {
                Write-Error "Could not parse the string: $_"
                continue
            }

            # Create a custom object with properties from the data hashtable
            $result = New-Object -TypeName PSObject -Property $data

            # Add the result to the array
            $results += $result
        }

        # Return the array of results
        return $results
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
        Repair-GitFolder $folder
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
        [string]$ConfigPath # The path of the config file
    )

    # Get the path to the git config file
    $configFile = Join-Path -Path $toRepair -ChildPath "\config"

    if (-not (Test-Path $configFile)) {
        Write-Error "Invalid folder path: $toRepair"  
    }
    else
    {
        Remove-Worktree -ConfigPath $toRepair
    }

}


function fix-CorruptedGitModulesCombinedWithQue {
        
    # Synopsis: A script to process files with git status and repair them if needed
    # Parameter: Start - The start path to process
    # Parameter: Modules - The path to the modules folder
    param (
        [Parameter(Mandatory=$true)]
        [string]$Start,
        [Parameter(Mandatory=$true)]
        [string]$Modules
    )

    # Call the main function
    Process-Files -Start $Start -Modules $Modules
}

# \GetWorktreeSubmodules.ps1

#This script adds git submodules to a working path based on the .gitmodules file
#Define a function to split a text file by a regular expression


#Define a function to add git submodules to a working path based on the .gitmodules file
function GitInitializeBySubmodule {

<#
.SYNOPSIS
Adds git submodules to a working path based on the .gitmodules file.

.PARAMETER WorkPath
The working path where the .gitmodules file is located.

.EXAMPLE
GitInitializeBySubmodule -WorkPath 'B:\ToGit\Projectfolder\NewWindows\scoopbucket-1'

#>

# Validate the parameter
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
    [string]$WorkPath
)

    # Set the execution policy to bypass for the current process
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

    # Set the regular expression to use for splitting
    $rgx = "submodule"

    # Change the current directory to the working path
    Set-Location $WorkPath

    # Set the path to the .gitmodules file
    $p = Join-Path $WorkPath ".gitmodules"

    # Split the text in the .gitmodules file by the regular expression and store the results in a variable
    $TextRanges = Split-TextByRegex -Path $p -Regx $rgx

    # Convert the key-value pairs in the text ranges to custom objects and store the results in a variable
    $zz = $TextRanges | ForEach-Object {
        try {
            # Trim and join the values in each text range
            $q = $_.value.trim() -join ","
        }
        catch {
            # If trimming fails, just join the values
            $q = $_.value -join ","
        }
        try {
            # Split the string by commas and equal signs and create a hashtable with the path and url keys
            $t = @{
                path = $q.Split(',')[0].Split('=')[1].trim()
                url = $q.Split(',')[1].Split('=')[1].trim()
            }
        }
        catch {
            # If splitting fails, just use the string as it is
            $t = $q
        }
        # Convert the hashtable to a JSON string and then back to a custom object
        $t | ConvertTo-Json | ConvertFrom-Json
    }

    # Filter out the custom objects that have a path property and loop through them
    $zz | Where-Object {($_.path)} | ForEach-Object {
        # Try to add a git submodule using the path and url properties
        try {
            Invoke-Git ("submodule add -f " + $_.url +" " + $_.path)
        }
        catch {
            Write-Error "Could not add git submodule: $_"
        }
    }
}

<#
.SYNOPSIS
Extracts submodules from a git repository.

.DESCRIPTION
Extracts submodules from a git repository by moving the .git directories from the submodules to the parent repository and updating the configuration.

.PARAMETER Paths
The paths of the submodules to extract. If not specified, all submodules are extracted.

.EXAMPLE
Extract-Submodules

.EXAMPLE
Extract-Submodules "foo" "bar"
[alias]
    extract-submodules = "!gitextractsubmodules() { set -e && { if [ 0 -lt \"$#\" ]; then printf \"%s\\n\" \"$@\"; else git ls-files --stage | sed -n \"s/^160000 [a-fA-F0-9]\\+ [0-9]\\+\\s*//p\"; fi; } | { local path && while read -r path; do if [ -f \"${path}/.git\" ]; then local git_dir && git_dir=\"$(git -C \"${path}\" rev-parse --absolute-git-dir)\" && if [ -d \"${git_dir}\" ]; then printf \"%s\t%s\n\" \"${git_dir}\" \"${path}/.git\" && mv --no-target-directory --backup=simple -- \"${git_dir}\" \"${path}/.git\" && git --work-tree=\"${path}\" --git-dir=\"${path}/.git\" config --local --path --unset core.worktree && rm -f -- \"${path}/.git~\" && if 1>&- command -v attrib.exe; then MSYS2_ARG_CONV_EXCL=\"*\" attrib.exe \"+H\" \"/D\" \"${path}/.git\"; fi; fi; fi; done; }; } && gitextractsubmodules"

    git extract-submodules [<path>...]
#>
function Extract-Submodules {
    param (
        [string[]]$Paths
    )

    # get the paths of all submodules if not specified
    if (-not $Paths) {
        $Paths = Get-SubmodulePaths
    }

    # loop through each submodule path
    foreach ($Path in $Paths) {
        $gg = "$Path/.git"
        
        # check if the submodule has a .git file
        if (Test-Path -Path "$gg" -PathType Leaf) {
            # get the absolute path of the .git directory
            $GitDir = Get-GitDir -Path $Path

            # check if the .git directory exists
            if (Test-Path -Path $GitDir -PathType Container) {
                # display the .git directory and the .git file
                Write-Host "$GitDir`t$gg"

                # move the .git directory to the submodule path
                Move-Item -Path $GitDir -Destination "$gg" -Force -Backup

                # unset the core.worktree config for the submodule
                Remove-Worktree -ConfigPath "$gg/config"

                # remove the backup file if any
                Remove-Item -Path "$gg~" -Force -ErrorAction SilentlyContinue

                # hide the .git directory on Windows
                Hide-GitDir -Path $Path
            }
        }
    }
}

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
function Sync-Git-Submodules {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $GitDirPath,

        [Parameter(Mandatory = $true)]
        [string]
        $GitRootPath,

        [Parameter(Mandatory = $false)]
        [switch]
        $FlagConfigDecides
    )

    # Import the helper modules
    Import-Module Git-helper
    Import-Module ini-helper

    $configPath = (Join-Path -Path $GitDirPath -ChildPath "config")

    # Get the config file content and select the submodule section
    $rootKnowledge = Get-IniContent -Path $configPath | Select-Object -Property submodule

    # Change the current location to the git root directory
    Set-Location -Path $GitRootPath

    # Loop through each submodule in the config file
    foreach ($rootx in $rootKnowledge) {
        try {
            # Change the current location to the submodule path
            Set-Location -Path $rootx.path

            # Get the remote URL of the submodule
            $q = Get-GitRemoteUrl

            # Check if the remote URL is a local path or empty
            $isPath = Test-Path -Path $q -IsValid
            $isEmpty = [string]::IsNullOrEmpty($q)

            if ($isPath -or $isEmpty) {
                # Set the remote URL to the one in the config file and overwrite it
                Set-GitRemote -Url $rootx.url -Overwrite
            }
            else {
                # Check if the URL in the config file is a local path or empty
                $isConfigPath = Test-Path -Path $rootx.url -IsValid
                $isConfigEmpty = [string]::IsNullOrEmpty($rootx.url)

                if ($isConfigEmpty) {
                    # Append the submodule to the config file
                    $rootx | Add-IniElement -Path $configPath
                }
                elseif ($isConfigPath) {
                    # Append the remote URL to the submodule and replace it in the config file
                   # ($rootx + AppendProperty($q)) | Set-IniElement -Path $configPath -OldElement $rootx
                }
                elseif ($rootx.url -notin $q.url) {
                    # Handle conflicting URLs
                    if ($FlagConfigDecides) {
                        # Use the config file as the source of truth and replace it in the submodule path
                        $rootx | Set-IniElement -Path (Join-Path -Path $rootx.path -ChildPath ".gitmodules") -OldElement $q
                    }
                    else {
                        # Throw an error for conflicting URLs
                        throw "Conflicting URLs: $($rootx.url) and $($q.url)"
                    }
                }
            }
        }
        catch {
            # Handle errors based on their messages
            switch ($_.Exception.Message) {
                "path not existing" {
                    return "uninitialized"
                }
                "path existing but no subroot present" {
                    return "already in index"
                }
                "path existing, git root existing, but git not recognized" {
                    return "corrupted"
                }
                default {
                    return $_.Exception.Message
                }
            }
        }
    }
}
# \GitUpdateSubmodulesAutomatically.ps1
<#
.SYNOPSIS
Updates the submodules of a git repository.

.DESCRIPTION
This function updates the submodules of a git repository, using the PsIni module and the git commands. The function removes any broken submodules, adds any new submodules, syncs the submodule URLs with the .gitmodules file, and pushes the changes to the remote repository.

.PARAMETER RepositoryPath
The path of the git repository where the submodules are located.

.PARAMETER SubmoduleNames
An array of submodule names that will be updated. If not specified, all submodules will be updated.
#>
function Update-Git-Submodules {
  [CmdletBinding()]
  param (
      [Parameter(Mandatory = $true)]
      [string]
      $RepositoryPath,

      [Parameter(Mandatory = $false)]
      [string[]]
      $SubmoduleNames
  )

    # Set the error action preference to stop on any error
    $ErrorActionPreference = "Stop"

    # Import the PsIni module
    Import-Module PsIni

    # Change the current location to the repository path
    Set-Location -Path $RepositoryPath

    # Get all submodules from the .gitmodules file as an array of objects
    $submodules = Get-IniContent -Path ".gitmodules" | Select-Object -Property submodule

    # If submodule names are specified, filter out only those submodules from the array
    if ($SubmoduleNames) {
        $submodules = $submodules | Where-Object { $_.submodule.Name -in $SubmoduleNames }
    }

    # Loop through each submodule in the array and update it
    foreach ($submodule in $submodules) {
            
        # Get submodule name and path from ini object properties
        
        $submoduleName = $submodule.submodule.Name
        
        $submodulePath = Join-Path -Path (Split-Path -Path ".gitmodules") -ChildPath ($submodule.submodule.path)
        
        # Check if submodule directory exists
        
        if (Test-Path -Path $submodulePath) {
            
            # Change current location to submodule directory
            
            Push-Location -Path $submodulePath
            
            # Get submodule URL from git config
            
            $submoduleUrl = Get-GitRemoteUrl
            
            # Check if submodule URL is empty or local path
            
            if ([string]::IsNullOrEmpty($submoduleUrl) -or (Test-Path -Path $submoduleUrl)) {
            
            # Set submodule URL to remote origin URL
            
            Set-GitRemoteUrl -Url (byPath-RepoUrl -Path $submodulePath)
            
            }
            
            # Return to previous location
            
            Pop-Location
            
            # Update submodule recursively
            
            Invoke-Git "submodule update --init --recursive $submodulePath"
            
        }
        
        else {
            
            # Add submodule from remote URL
            
            Invoke-Git "submodule add $(byPath-RepoUrl -Path $submodulePath) $submodulePath"
            
        }
    
    }

  # Sync the submodule URLs with the .gitmodules file
  Invoke-Git "submodule sync"

  # Push the changes to the remote repository
  Invoke-Git "push origin master"
}




# \git_add_submodule.ps1
#Get-Content .\.gitmodules | ? { $_ -match 'url' } | % { ($_ -split "=")[1].trim() } 
function git_add_submodule () {
    Write-Host "[Add Git Submodule from .gitmodules]" -ForegroundColor Green
    Write-Host "... Dump git_add_submodule.temp ..." -ForegroundColor DarkGray
    git config -f .gitmodules --get-regexp '^submodule\..*\.path$' > git_add_submodule.temp

    Get-content git_add_submodule.temp | ForEach-Object {
            try {
                $path_key, $path = $_.split(" ")
                $url_key = "$path_key" -replace "\.path",".url"
                $url= git config -f .gitmodules --get "$url_key"
                Write-Host "$url  -->  $path" -ForegroundColor DarkCyan
                Invoke-Git "submodule add $url $path"
            } catch {
                Write-Host $_.Exception.Message -ForegroundColor Red
                continue
            }
        }
    Write-Host "... Remove git_add_submodule.temp ..." -ForegroundColor DarkGray
    Remove-Item git_add_submodule.temp
}

#Git-InitializeSubmodules -repoPath 'G:\ToGit\projectFolderBare\scoopbucket-presist'

function fix-CorruptedGitModules ($folder = "C:\ProgramData\scoop\persist", $modules = "C:\ProgramData\scoop\persist\.git\modules")
{
    begin {
        Push-Location

        # Validate the arguments
        Validate-Arguments $modules $folder

        # Set the environment variable for git error redirection
        $env:GIT_REDIRECT_STDERR = '2>&1'
    }
    process {
        # Get the list of folders in $folder
        $folders = Get-ChildItem -Path $folder -Directory

        # Loop through each folder and run git status
        foreach ($f in $folders) {
            # Change the current directory to the folder
            Set-Location $f.FullName
            Write-Output "checking $f"
            if ((Get-ChildItem -force | ?{ $_.name -eq ".git" } ))
            {
            # Run git status and capture the output
            $output = Check-GitStatus $f.FullName
            
            if(($output -like "fatal*"))
            { 
                    Write-Output "fatal status for $f"
                    $f | Get-ChildItem -force | ?{ $_.name -eq ".git" } | % {
                    $toRepair = $_
            
                if( $toRepair -is [System.IO.FileInfo] )
                {
                    $modules | Get-ChildItem -Directory | ?{ $_.name -eq $toRepair.Directory.Name } | select -First 1 | % {
                        # Move the folder to the target folder
                        rm $toRepair -force ; Move-Item -Path $_.fullname -Destination $toRepair -force }
                    }
                    else
                    {
                        Write-Error "not a .git file: $toRepair"
                    }

                    if( $toRepair -is [System.IO.DirectoryInfo] )
                    {
                        Remove-Worktree "$toRepair/config"
                    }
                    else
                    {
                        Write-Error "not a .git folder: $toRepair"
                    }

                }
            }
            else
            {
                Write-Output @($output)[0]
            }

            }
            else
            {
                Write-Output "$f not yet initialized"
            }
        }
    }
    end
         {
 Pop-Location
    }

}



function GetWorktreeSubmodules {
   
    # Synopsis: A script to get the submodules recursively for a given repo path or a list of repo paths
    # Parameter: RepoPaths - The path or paths to the repos
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$RepoPaths # The path or paths to the repos
    )

    # A function to validate a path argument
    # Call the main function for each repo path in the pipeline
    foreach ($RepoPath in $RepoPaths) {
      Get-SubmodulesRecursive -RepoPath $RepoPath
    }
}
# \GitfixSubmoduleWithModulePath.ps1
function GitfixSubmoduleWithModulePath {
    [CmdletBinding()]
        
    <#todo
    fallback solutions
    * if everything fails,
        set got dir path to abbsolute value and edit work tree in place
    * if comsumption fails,
        due to modulefolder exsisting, revert move and trye to use exsisting folder instead,
        if this ressults in error, re revert to initial
        move inplace module to x prefixed
        atempt to consume again
    * if no module is provided, utelyse everything to find possible folders
        use hamming distance like priorit order
        where
        1. exact parrentmatch
        rekative to root
            order resukts by total exact


        take first precedance
        2. predefined patterns taken
        and finaly sort rest by hamming
    #>

    # This script converts a git folder into a submodule and absorbs its git directory

    param (
        [Parameter(Mandatory=$true, HelpMessage=".git, The path of the git folder to convert")]
        [ValidateScript({Test-Path $_ -PathType Container ; Resolve-Path -Path $_ -ErrorAction Stop})] 
        [Alias("GitFolder")][string]$errorus,[Parameter(Mandatory=$true,HelpMessage="subModuleRepoDir, The path of the submodule folder to replace the git folder")]
        #can be done with everything and menu
        [Parameter(Mandatory=$true,HelpMessage="subModuleDirInsideGit")]
        [ValidateScript({Test-Path $_ -PathType Container ; Resolve-Path -Path $_ -ErrorAction Stop})]
        [Alias("SubmoduleFolder")][string]$toReplaceWith
    )
    begin {
        $pastE = $error
        $error.Clear()

        Get-ChildItem -path B:\GitPs1Module\* -Filter '*.ps1' | % { . $_.FullName }
        
        # Save the previous error action preference
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Stop"

    }
    process {


    # Get the target folder, name and parent path from the git folder
        Write-Verbos "#---- asFile"
        $asFile = ([System.IO.Fileinfo]$errorus.trim('\'))
        Write-Verbos $asFile
        $targetFolder = $asFile.Directory
        $name = $targetFolder.Name
        $path = $targetFolder.Parent.FullName

        # Get the config file path from the git folder
        $configFile = Join-Path $GitFolder 'config'

        about-Repo #does nothing without -verbos

        # Move the git folder to a temporary name
        Move-Folder -Source $GitFolder -Destination (Join-Path $targetFolder 'x.git')

        # Move the submodule folder to replace the git folder
        Move-Folder -Source $SubmoduleFolder -Destination (Join-Path $targetFolder '.git')

        # Remove the worktree line from the config file
        (Get-Content -Path $configFile | Where-Object { ! ($_ -match 'worktree') }) | Set-Content -Path $configFile

        # Push the current location and change to the target folder
        Push-Location
        Set-Location $targetFolder
        
        index-Remove $name	$path

        # Change to the parent path and get the root of the git repository
        
        # Add and absorb the submodule using the relative path and remote url
        $relative = get-Relative $path $targetFolder

        Add-AbsorbSubmodule -Ref ( get-Origin) -Relative $relative

        # Pop back to the previous location
        Pop-Location

        # Restore the previous error action preference
        $ErrorActionPreference = $previousErrorAction

    }
}