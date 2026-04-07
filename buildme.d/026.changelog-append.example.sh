#!/bin/bash
# 026.changelog-append.example.sh
# Prepends a CHANGELOG.md entry for the new version using git log
# since the previous tag. Commit the updated file as part of your release.

CHANGELOG="${GIT_ROOT}/CHANGELOG.md"
DATE=$(date '+%Y-%m-%d')

# Collect commits since last tag
PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
if [[ -n "$PREV_TAG" ]]; then
    COMMITS=$(git log --oneline "${PREV_TAG}..HEAD" 2>/dev/null | sed 's/^/- /')
else
    COMMITS=$(git log --oneline | tail -20 | sed 's/^/- /')
fi

if [[ -z "$COMMITS" ]]; then
    echo -e "${YELLOW}⚠️  No commits to log since ${PREV_TAG:-beginning}. Skipping changelog.${RESET}"
    return 0
fi

ENTRY=$(cat <<EOF
## [${NEW_VERSION}] — ${DATE}

${COMMITS}

EOF
)

echo -e "${BLUE}📓 Prepending CHANGELOG.md entry for ${NEW_VERSION}...${RESET}"

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[dry-run] Would prepend to ${CHANGELOG}:${RESET}"
    echo "$ENTRY"
    return 0
fi

if [[ -f "$CHANGELOG" ]]; then
    TMP=$(mktemp)
    { echo "$ENTRY"; cat "$CHANGELOG"; } > "$TMP"
    mv "$TMP" "$CHANGELOG"
else
    echo "$ENTRY" > "$CHANGELOG"
fi

echo -e "${GREEN}✅ CHANGELOG.md updated.${RESET}"
