# ------------------------------------------
# .aliases/bitwarden
# ------------------------------------------
# Plain .zsh, not .tmpl: the output contains chezmoi template syntax.

# rbw has a different CLI; helpers that need Bitwarden's commands use command bw.
if (( $+commands[rbw] )); then
    alias bw=rbw
fi

# print a .chezmoi.toml.tmpl lookup block for each Bitwarden item matching
# <search>, limited to the named custom fields (all fields when none given).
# only item ids and field names are printed, never field values.
cz-bw-fields() {
    if (( $# < 1 )); then
        print -u2 'usage: cz-bw-fields <search> [field...]'
        return 2
    fi
    local tool
    for tool in bw jq; do
        whence -p "$tool" >/dev/null || {
            print -u2 "cz-bw-fields: $tool not on PATH"
            return 127
        }
    done

    local search=$1 items
    shift
    items=$(command bw list items --search "$search") || return
    if [[ $(jq length <<<"$items") == 0 ]]; then
        print -u2 "cz-bw-fields: no items match '$search'"
        return 1
    fi

    jq -r --args '
        $ARGS.positional as $want
        | [.[]
          | ("bw_" + (.name | ascii_downcase | gsub("[^a-z0-9_]"; "_"))) as $var
          | ["# \(.name)",
             "{{- $\($var) := bitwardenFields \"item\" \"\(.id)\" }}",
             "[data.\($var)]",
             (.fields[]? | .name as $f
              | select(($want | length) == 0 or any($want[]; . == $f))
              | if $f | test("^[A-Za-z_][A-Za-z0-9_]*$")
                then "  \($f) = {{ $\($var).\($f).value | quote }}"
                else "  \($f | gsub("[^A-Za-z0-9_]"; "_")) = {{ (index $\($var) \"\($f)\").value | quote }}"
                end)]
          | join("\n")]
        | join("\n\n")' "$@" <<<"$items"
}
