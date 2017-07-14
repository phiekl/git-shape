## About
Use this "git addon" to create a new branch of your repo, where the mentioned
files/dirs are either removed (=blacklist) or are the only ones that are kept
(=whitelist). In both cases the history is affected as well.

## Installation
Put the script wherever you want, e.g. *~/bin/git-shape*.

Add it to your *[alias]* section in *~/.gitconfig*:
```
shape = !~/bin/git-shape
```

## Usage
Change directory to some git repository where you'd like to delete everything
except the paths you specify (files and/or dirs), and then run it like this:
```
git shape -w file1 dir1 file2
```

This creates and switches to a new branch. Afterwards, the only files/dir found
in the branch are file1, file2 and dir1. The history will only contain these
items. The branch is now ready to be merged into another repo or a new one.

To do the opposite, keeping everything but the mentioned files/dirs, use `-b`
instead of `-w`.
