#!/bin/bash
# 023.trigger-pipeline.example.sh
# Triggers a downstream CI/CD pipeline via repository_dispatch (GitHub/Gitea)
# or a generic webhook. Useful for kicking off integration tests or a
# GitOps promotion workflow after images are pushed.

# Gitea / GitHub repository dispatch
DISPATCH_HOST="https://git.nillth.net"    # or https://api.github.com
DISPATCH_TOKEN="${GITEA_TOKEN:-${GITHUB_TOKEN:-}}"
DISPATCH_OWNER="$GIT_OWNER"
DISPATCH_REPO="$PROJECT_NAME"
DISPATCH_EVENT="image-published"           # must match 'on.repository_dispatch.types' in workflow

if [[ -z "$DISPATCH_TOKEN" ]]; then
    echo -e "${YELLOW}⚠️  No GITEA_TOKEN or GITHUB_TOKEN set. Skipping pipeline trigger.${RESET}"
    return 0
fi

if [[ "$SKIP_PUSH" == true ]]; then
    echo -e "${YELLOW}⏭️  Skipping pipeline trigger (push was skipped).${RESET}"
    return 0
fi

PAYLOAD=$(cat <<EOF
{
  "event_type": "${DISPATCH_EVENT}",
  "client_payload": {
    "version": "${NEW_VERSION}",
    "images": $(printf '%s\n' "${BUILT_REPOS[@]}" | jq -Rs 'split("\n") | map(select(length > 0))')
  }
}
EOF
)

if [[ "$DISPATCH_HOST" == *"github.com"* ]]; then
    API_URL="${DISPATCH_HOST}/repos/${DISPATCH_OWNER}/${DISPATCH_REPO}/dispatches"
else
    API_URL="${DISPATCH_HOST}/api/v1/repos/${DISPATCH_OWNER}/${DISPATCH_REPO}/hooks"
fi

echo -e "${BLUE}🚀 Triggering pipeline event '${DISPATCH_EVENT}' on ${DISPATCH_REPO}...${RESET}"
run_cmd curl -fsSL -X POST \
    -H "Authorization: token ${DISPATCH_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$PAYLOAD" \
    "$API_URL"
echo -e "${GREEN}✅ Pipeline triggered.${RESET}"
