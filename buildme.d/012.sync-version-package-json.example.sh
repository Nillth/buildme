#!/bin/bash
# 012.sync-version-package-json.example.sh
# Writes the new build version into package.json.
# Useful when you want the JS bundle's reported version to match the image tag.

PACKAGE_JSON="${GIT_ROOT}/package.json"

if [[ ! -f "$PACKAGE_JSON" ]]; then
    echo -e "${YELLOW}⚠️  No package.json found. Skipping.${RESET}"
    return 0
fi

echo -e "${BLUE}📝 Updating package.json version → ${NEW_VERSION}${RESET}"
# Use a temp file to avoid in-place sed portability issues
TMP=$(mktemp)
run_cmd sed "s/\"version\": \"[^\"]*\"/\"version\": \"${NEW_VERSION}\"/" "$PACKAGE_JSON" > "$TMP"
[[ "$DRY_RUN" == false ]] && mv "$TMP" "$PACKAGE_JSON" || rm -f "$TMP"
echo -e "${GREEN}✅ package.json updated.${RESET}"
