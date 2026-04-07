#!/bin/bash
# 002.azure-containerapp.sh
# Updates the Azure Container App after a successful push.

AZ_APP_NAME="cso-web"
AZ_RESOURCE_GROUP="CSO_Resources"

if [[ "$SKIP_PUSH" == true ]]; then
    echo -e "${YELLOW}⏭️  Skipping Azure container app update (push was skipped).${RESET}"
    return 0
fi

if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}⚠️  Uncommitted changes detected. Skipping Azure container app update.${RESET}"
    git status -s
    return 0
fi

IMAGE_REPO="${BUILT_REPOS[0]}"

echo -e "${GREEN}☁️  Updating Azure Container App '${AZ_APP_NAME}' → ${IMAGE_REPO}:${NEW_VERSION}${RESET}"
run_cmd az containerapp update \
    --name "$AZ_APP_NAME" \
    --resource-group "$AZ_RESOURCE_GROUP" \
    --image "registry.hub.docker.com/${IMAGE_REPO}:${NEW_VERSION}"
echo -e "${GREEN}✅ Azure Container App updated.${RESET}"
