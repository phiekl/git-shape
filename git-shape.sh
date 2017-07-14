#!/bin/bash

syntax()
{
  printf 'syntax: git shape [-b|-w] <file/dir_path_in_repo>..\n' 1>&2
  exit 1
}
[ -n "$2" ] || syntax
[[ $1 =~ ^-[bw]$ ]] || syntax

mode="$1"
shift

set -e

tmpscript="$(mktemp)"
trap 'rm "$tmpscript"' EXIT

tmpname="${tmpscript##*/}" # just get the unique name

# Find all alternative old names of these paths.
paths=()
while read -r path; do
  [ -n "$path" ] || continue
  paths+=("$path")
done < <(
  for path; do
    git log --name-only --format=format: --follow -- "$path"
  done | sort -V | uniq
)

if [ "$mode" == '-b' ]; then
  cat << EOF > "$tmpscript"
#!/bin/bash
rm -rf $(printf ' "./%s"' "${paths[@]}") 2>&-
exit 0
EOF
else
  cat << EOF > "$tmpscript"
#!/bin/bash
mkdir -p "$tmpname"
mv$(printf ' "%s"' "${paths[@]}") "$tmpname" 2>&-
exit 0
EOF
fi

chmod +x "$tmpscript"

ls -al
set -x
git checkout -b "$tmpname"
git filter-branch -f --prune-empty --tree-filter "$tmpscript" HEAD
[ "$mode" == '-w' ] && \
  git filter-branch -f --prune-empty --subdirectory-filter "$tmpname"
