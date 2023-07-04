﻿<#This git statement uses the git filter-branch command, which lets you rewrite Git revision history by applying custom filters on each revision1. The statement has the following parts:

-f or –force: This option forces the command to proceed even if the refs have already been rewritten by a previous run of git filter-branch1.
–index-filter: This option specifies a filter that modifies the index of each revision. The filter is given as a shell command that is evaluated using the eval command1. The filter should use git update-index directly to manipulate the index1.
“git ls-files --ignored --exclude-standard -c | xargs -r git rm”: This is the shell command that is used as the index filter. It does the following:
git ls-files --ignored --exclude-standard -c: This lists all the files that are ignored by .gitignore or other exclude files, and also have their content cached in the index2.
xargs -r git rm: This passes each file name from the previous command as an argument to git rm, which removes them from the index and the working tree3. The -r option prevents xargs from running git rm if there are no arguments4.
–prune-empty: This option tells git filter-branch to remove commits that become empty (i.e. have no changes) after applying the filters1.
So, in summary, this git statement rewrites the history of the current branch by removing all the ignored files from each revision, and also removing any empty commits that result from this operation. It does this by modifying only the index, not the working tree, of each revision.#>


#-f to overwrite preivius filterbranch backup
# git ls-files --ignored
# lists ignored files
# --exclude-standard
# utelizes the exclude file aditional to ignore
# -c
# include cached aka indexed
# xargs -r
# don't run if xargs is passed a empty set.

git filter-branch -f --index-filter "git ls-files --ignored --exclude-standard -c | xargs -r git rm"  --prune-empty

;
