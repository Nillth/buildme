#!/bin/bash
# 006.git-tag-release.example.sh
# Creates and pushes a git tag for the new version.
# Skips if the tag already exists (e.g. from a re-run on the same version).

TAG="v${NEW_VERSION}"

if git rev-parse "$TAG" &>/dev/null; then
    echo -e "${YELLOW}⚠️  Git tag ${TAG} already exists. Skipping.${RESET}"
    return 0
fi

if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}⚠️  Uncommitted changes detected. Skipping git tag.${RESET}"
    return 0
fi

echo -e "${BLUE}🏷️  Creating git tag ${TAG}...${RESET}"
run_cmd git tag -a "$TAG" -m "Release ${TAG}"
run_cmd git push origin "$TAG"
echo -e "${GREEN}✅ Tagged and pushed ${TAG}.${RESET}"
