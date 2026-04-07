#!/bin/bash
# 009.kubectl-rollout.example.sh
# Updates a Kubernetes deployment image and waits for rollout to complete.
# Requires kubectl configured with the correct context.

K8S_NAMESPACE="default"
K8S_DEPLOYMENT="${PROJECT_NAME}"
# In multi-service mode, map service names to deployment names if they differ:
#   K8S_DEPLOYMENT="${PROJECT_NAME}-backend"

if [[ "$SKIP_PUSH" == true ]]; then
    echo -e "${YELLOW}⏭️  Skipping Kubernetes rollout (push was skipped).${RESET}"
    return 0
fi

IMAGE_REPO="${BUILT_REPOS[0]}"
CONTAINER_NAME="${PROJECT_NAME}"  # adjust if container name differs from deployment

echo -e "${BLUE}☸️  Rolling out ${K8S_DEPLOYMENT} → ${IMAGE_REPO}:${NEW_VERSION}${RESET}"
run_cmd kubectl set image "deployment/${K8S_DEPLOYMENT}" \
    "${CONTAINER_NAME}=${IMAGE_REPO}:${NEW_VERSION}" \
    --namespace "$K8S_NAMESPACE"

run_cmd kubectl rollout status "deployment/${K8S_DEPLOYMENT}" \
    --namespace "$K8S_NAMESPACE" \
    --timeout=120s

echo -e "${GREEN}✅ Kubernetes rollout complete.${RESET}"
