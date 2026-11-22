# ------------------------------------------
# .aliases/thaw
# ------------------------------------------

# save Thaw profiles into chezmoi; click Update on the profile in Thaw first
cz-thaw-update() {
    local live="$HOME/Library/Application Support/Thaw/Profiles"
    local repo
    repo="$(chezmoi source-path)/Library/Application Support/Thaw/Profiles" || return
    # Mirror the live folder so profiles deleted in Thaw leave the repo too.
    rm -f "$repo"/create_*.json
    local f
    for f in "$live"/*.json; do
        cp "$f" "$repo/create_${f:t}"
    done
}
