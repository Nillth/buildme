#!/bin/bash
# 024.flyio-deploy.example.sh
# Deploys to Fly.io using flyctl after a successful push.
# The image must be accessible from Fly's build infrastructure, so
# this works best when your registry is public or Fly has pull access.
# Docs: https://fly.io/docs/flyctl/

FLY_APP="${PROJECT_NAME}"   # fly app name (matches fly.toml app = "...")
FLY_CONFIG="${GIT_ROOT}/fly.toml"

if ! command -v flyctl &>/dev/null; then
    echo -e "${YELLOW}⚠️  flyctl not found in PATH. Skipping Fly.io deploy.${RESET}"
    return 0
fi

if [[ "$SKIP_PUSH" == true ]]; then
    echo -e "${YELLOW}⏭️  Skipping Fly.io deploy (push was skipped).${RESET}"
    return 0
fi

if [[ ! -f "$FLY_CONFIG" ]]; then
    echo -e "${YELLOW}⚠️  No fly.toml found at ${FLY_CONFIG}. Skipping.${RESET}"
    return 0
fi

IMAGE_REPO="${BUILT_REPOS[0]}"

echo -e "${BLUE}🪂 Deploying ${FLY_APP} → ${IMAGE_REPO}:${NEW_VERSION}${RESET}"
run_cmd flyctl deploy \
    --app "$FLY_APP" \
    --config "$FLY_CONFIG" \
    --image "${IMAGE_REPO}:${NEW_VERSION}"
echo -e "${GREEN}✅ Fly.io deploy complete.${RESET}"
