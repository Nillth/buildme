#!/bin/bash
# 001.example.sh — example post-build hook
# Copy this file, rename it (e.g. 001.azure-containerapp.sh), and customise.
# This file is sourced by buildme.sh after build+push completes.
#
# Available variables:
#   NEW_VERSION   — e.g. 0.26097.3
#   BUILT_REPOS   — array of image repo paths (e.g. git.example.com/owner/project)
#   ENGINE        — "docker" or "podman"
#   SKIP_PUSH     — "true" if --skip-push was passed
#   DRY_RUN       — "true" if --dry-run was passed
#   GIT_SERVER, GIT_OWNER, PROJECT_NAME — from git remote
#   GIT_ROOT      — absolute path to the repo root
#   run_cmd       — wrapper that respects --dry-run
#
# Use 'return 0' (not 'exit') to bail out early.

echo -e "${BLUE}💡 Example hook: NEW_VERSION=${NEW_VERSION}, images=${BUILT_REPOS[*]}${RESET}"

# Example: update an Azure Container App
# AZ_APP_NAME="my-app"
# AZ_RESOURCE_GROUP="my-rg"
# [[ "$SKIP_PUSH" == true ]] && { echo -e "${YELLOW}⏭️  Skipping (push was skipped).${RESET}"; return 0; }
# run_cmd az containerapp update \
#     --name "$AZ_APP_NAME" \
#     --resource-group "$AZ_RESOURCE_GROUP" \
#     --image "registry.hub.docker.com/${BUILT_REPOS[0]}:${NEW_VERSION}"
