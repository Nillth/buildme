#!/bin/bash
# 013.sync-version-cargo-toml.example.sh
# Writes the new build version into Cargo.toml.
# Only updates the first [package] version line to avoid touching dependency versions.

CARGO_TOML="${GIT_ROOT}/Cargo.toml"

if [[ ! -f "$CARGO_TOML" ]]; then
    echo -e "${YELLOW}⚠️  No Cargo.toml found. Skipping.${RESET}"
    return 0
fi

echo -e "${BLUE}📝 Updating Cargo.toml version → ${NEW_VERSION}${RESET}"
TMP=$(mktemp)
# Only replace the first occurrence (the [package] block version)
run_cmd awk -v ver="$NEW_VERSION" '
    !done && /^version = "/ { sub(/^version = "[^"]*"/, "version = \"" ver "\""); done=1 }
    { print }
' "$CARGO_TOML" > "$TMP"
[[ "$DRY_RUN" == false ]] && mv "$TMP" "$CARGO_TOML" || rm -f "$TMP"
echo -e "${GREEN}✅ Cargo.toml updated.${RESET}"
