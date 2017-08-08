#!/bin/bash

die()
{
  printf '%s\n' "$1" 1>&2
  exit 1
}

syntax()
{
  cat 1>&2 << EOF
syntax: git shape <-b|-w> [-d <dir>] [-f <file>] <file/dir_path_in_repo>..
EOF
  exit 1
}
[ -n "$2" ] || syntax

unset final_dir final_fn mode

while [ -n "${1+set}" ]; do
  case "$1" in
    '-b')
      mode='blacklist'
      shift
      ;;
    '-d')
      final_dir="$2"
      shift 2
      ;;
    '-f')
      final_fn="$2"
      shift 2
      ;;
    '-w')
      mode='whitelist'
      shift
      ;;
    '--')
      shift
      break
      ;;
    -*)
      syntax
      ;;
    *)
      break
      ;;
  esac
done

[ -n "$mode" ] || syntax

[ -n "$final_fn" -a "$#" -gt '1' ] && \
  die "Only a single file/dir path may be supplied with -f."

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

if [ "$mode" == 'blacklist' ]; then
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

set -x
git checkout -b "$tmpname"
git filter-branch -f --prune-empty --tree-filter "$tmpscript" HEAD
[ "$mode" == 'whitelist' ] && \
  git filter-branch -f --prune-empty --subdirectory-filter "$tmpname"
set +x

if [ -n "$final_dir" -o -n "$final_fn" ]; then
  if [ -n "$final_fn" ]; then
    final_dst="${final_dir:-.}/$final_fn"
  else
    final_dst="$final_dir"
  fi
  cat << EOF > "$tmpscript"
#!/bin/bash
mkdir -p "${final_dir:-.}"
find . -type f -exec mv '{}' "$final_dst" \; 2>&-
exit 0
EOF
  set -x
  git filter-branch -f --prune-empty --tree-filter "$tmpscript" HEAD
fi


cat << EOF

echo To rebase the results into another repo:

cd yourotherrepo
git remote add -t $tmpname tmpimport $(readlink -m .)
git fetch tmpimport
git rebase tmpimport/$tmpname
git pull --rebase
git remote remove tmpimport
EOF
