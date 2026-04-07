#!/bin/bash
# 007.update-compose-image.example.sh
# Updates the image tag(s) in a docker-compose.yml to the new version.
# Useful when your compose file pins an explicit tag and you want it
# committed alongside the build so deployments are reproducible.

COMPOSE_FILE="${GIT_ROOT}/docker-compose.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
    echo -e "${YELLOW}⚠️  No docker-compose.yml found at ${COMPOSE_FILE}. Skipping.${RESET}"
    return 0
fi

echo -e "${BLUE}📝 Updating image tags in docker-compose.yml...${RESET}"

for IMAGE_REPO in "${BUILT_REPOS[@]}"; do
    # Replace any existing tag (or :latest) for this repo with the new version
    # Matches lines like:  image: git.example.com/owner/project:0.26097.2
    run_cmd sed -i "s|${IMAGE_REPO}:[^[:space:]\"']*|${IMAGE_REPO}:${NEW_VERSION}|g" "$COMPOSE_FILE"
done

echo -e "${GREEN}✅ docker-compose.yml updated.${RESET}"
