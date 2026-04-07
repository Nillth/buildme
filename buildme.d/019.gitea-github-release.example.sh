#!/bin/bash
# 019.gitea-github-release.example.sh
# Creates a release on Gitea or GitHub with an auto-generated body
# summarising commits since the previous tag.
# Set RELEASE_HOST to your Gitea instance or "https://api.github.com".

RELEASE_HOST="https://git.nillth.net"   # Gitea base URL, or https://api.github.com
RELEASE_TOKEN="${GITEA_TOKEN:-${GITHUB_TOKEN:-}}"  # env var: GITEA_TOKEN or GITHUB_TOKEN
RELEASE_OWNER="$GIT_OWNER"
RELEASE_REPO="$PROJECT_NAME"
PRERELEASE=false

if [[ -z "$RELEASE_TOKEN" ]]; then
    echo -e "${YELLOW}⚠️  No GITEA_TOKEN or GITHUB_TOKEN set. Skipping release creation.${RESET}"
    return 0
fi

# Build release notes from commits since last tag
PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
if [[ -n "$PREV_TAG" ]]; then
    NOTES=$(git log --oneline "${PREV_TAG}..HEAD" 2>/dev/null | sed 's/^/- /')
else
    NOTES="Initial release"
fi

TAG="v${NEW_VERSION}"

PAYLOAD=$(cat <<EOF
{
  "tag_name": "${TAG}",
  "name": "${PROJECT_NAME} ${TAG}",
  "body": $(echo "$NOTES" | jq -Rs .),
  "draft": false,
  "prerelease": ${PRERELEASE}
}
EOF
)

# Gitea API path differs slightly from GitHub
if [[ "$RELEASE_HOST" == *"github.com"* ]]; then
    API_URL="${RELEASE_HOST}/repos/${RELEASE_OWNER}/${RELEASE_REPO}/releases"
else
    API_URL="${RELEASE_HOST}/api/v1/repos/${RELEASE_OWNER}/${RELEASE_REPO}/releases"
fi

echo -e "${BLUE}🏷️  Creating release ${TAG} on ${RELEASE_HOST}...${RESET}"
run_cmd curl -fsSL -X POST \
    -H "Authorization: token ${RELEASE_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$PAYLOAD" \
    "$API_URL"
echo -e "${GREEN}✅ Release ${TAG} created.${RESET}"
