#!/bin/bash
# 015.prune-old-images.example.sh
# Removes locally cached images for this project that are not :latest
# or the just-built version, keeping the last N versions on disk.
# Helps prevent unbounded disk growth on CI/build machines.

KEEP_LAST=3   # number of recent versioned tags to keep (excluding :latest)

echo -e "${BLUE}🧹 Pruning old local images (keeping last ${KEEP_LAST})...${RESET}"

for IMAGE_REPO in "${BUILT_REPOS[@]}"; do
    # List all tags for this repo, sorted oldest-first, exclude :latest and current version
    TAGS=$(  $ENGINE images --format '{{.Tag}}' "${IMAGE_REPO}" \
           | grep -v '^latest$' \
           | grep -v "^${NEW_VERSION}$" \
           | sort \
           | head -n -"$KEEP_LAST" )

    if [[ -z "$TAGS" ]]; then
        echo -e "${BLUE}   ${IMAGE_REPO}: nothing to prune${RESET}"
        continue
    fi

    while IFS= read -r TAG; do
        echo -e "${YELLOW}   removing ${IMAGE_REPO}:${TAG}${RESET}"
        run_cmd $ENGINE rmi "${IMAGE_REPO}:${TAG}" || true
    done <<< "$TAGS"
done

echo -e "${GREEN}✅ Prune complete.${RESET}"
