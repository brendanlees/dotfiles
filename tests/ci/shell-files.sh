#!/usr/bin/env bash

# Filter a NUL-delimited file list for ShellCheck. Templates are checked only
# after rendering; shebangs cover managed commands that have no shell suffix.
shell_files() {
  local path first_line
  while IFS= read -r -d '' path; do
    [[ -f $path && $path != *.tmpl ]] || continue
    IFS= read -r first_line <"$path" || true
    if [[ $path == *.sh ||
          $first_line =~ ^\#![[:space:]]*(/usr/bin/env[[:space:]]+)?(/[^[:space:]]*/)?(bash|sh|dash|ksh)([[:space:]]|$) ]]; then
      printf '%s\0' "$path"
    fi
  done
}
