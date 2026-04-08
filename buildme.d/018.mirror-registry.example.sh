#!/bin/bash
# 018.mirror-registry.example.sh
# Re-tags and pushes each built image to a secondary registry.
# Useful for mirroring to Docker Hub, GHCR, or an air-gapped registry
# in addition to your primary registry.

MIRROR_REGISTRY="${MIRROR_REGISTRY:-ghcr.io}"     # e.g. docker.io, ghcr.io, registry.example.com
MIRROR_OWNER="${MIRROR_OWNER:-your-org}"       # owner/namespace on the mirror

if [[ "$SKIP_PUSH" == true ]]; then
    echo -e "${YELLOW}⏭️  Skipping mirror push (push was skipped).${RESET}"
    return 0
fi

for IMAGE_REPO in "${BUILT_REPOS[@]}"; do
    # Derive the image name (last path segment)
    IMAGE_NAME="${IMAGE_REPO##*/}"
    MIRROR_REPO="${MIRROR_REGISTRY}/${MIRROR_OWNER}/${IMAGE_NAME}"

    for TAG in "${NEW_VERSION}" "latest"; do
        echo -e "${BLUE}🪞 Mirroring ${IMAGE_REPO}:${TAG} → ${MIRROR_REPO}:${TAG}${RESET}"
        run_cmd $ENGINE tag "${IMAGE_REPO}:${TAG}" "${MIRROR_REPO}:${TAG}"
        run_cmd $ENGINE push "${MIRROR_REPO}:${TAG}"
    done
    echo -e "${GREEN}✅ Mirrored ${IMAGE_NAME} to ${MIRROR_REGISTRY}.${RESET}"
done
