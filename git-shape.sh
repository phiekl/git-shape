#!/bin/bash

syntax()
{
  printf 'syntax: git shape <-b|-w> [-d <dir>] <file/dir_path_in_repo>..\n' 1>&2
  exit 1
}
[ -n "$2" ] || syntax

unset final_dir mode

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

if [ -n "$final_dir" ]; then
  unset basepaths
  declare -A basepaths
  for path in "${paths[@]}"; do
    basepaths["${path##*/}"]='set'
  done
  cat << EOF > "$tmpscript"
#!/bin/bash
mkdir -p "$final_dir"
mv$(printf ' "%s"' "${!basepaths[@]}") "$final_dir" 2>&-
exit 0
EOF
  set -x
  git filter-branch -f --prune-empty --tree-filter "$tmpscript" HEAD
fi
