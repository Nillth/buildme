#!/bin/bash
# 022.helm-values-update.example.sh
# Updates image tags in a Helm values.yaml file and optionally runs
# helm upgrade to apply the change to a cluster.

HELM_VALUES="${HELM_VALUES:-${GIT_ROOT}/helm/values.yaml}"
HELM_RELEASE="${HELM_RELEASE:-${PROJECT_NAME}}"
HELM_NAMESPACE="${HELM_NAMESPACE:-default}"
HELM_CHART_DIR="${HELM_CHART_DIR:-${GIT_ROOT}/helm}"
AUTO_UPGRADE=false   # set true to run 'helm upgrade' after patching values

if [[ ! -f "$HELM_VALUES" ]]; then
    echo -e "${YELLOW}⚠️  No Helm values.yaml found at ${HELM_VALUES}. Skipping.${RESET}"
    return 0
fi

echo -e "${BLUE}⎈  Updating Helm values: image tags → ${NEW_VERSION}${RESET}"

for IMAGE_REPO in "${BUILT_REPOS[@]}"; do
    # Matches:  tag: "0.26097.2"  or  tag: 0.26097.2
    # placed under a block that references this repo (best-effort; adjust key if needed)
    TMP=$(mktemp)
    run_cmd sed "s|${IMAGE_REPO}:[^[:space:]\"']*|${IMAGE_REPO}:${NEW_VERSION}|g" "$HELM_VALUES" > "$TMP"
    [[ "$DRY_RUN" == false ]] && mv "$TMP" "$HELM_VALUES" || rm -f "$TMP"
done

echo -e "${GREEN}✅ Helm values.yaml updated.${RESET}"

if [[ "$AUTO_UPGRADE" == true ]]; then
    if ! command -v helm &>/dev/null; then
        echo -e "${RED}❌ helm not found in PATH. Cannot run upgrade.${RESET}"
        return 1
    fi
    echo -e "${BLUE}⎈  Running helm upgrade ${HELM_RELEASE}...${RESET}"
    run_cmd helm upgrade "$HELM_RELEASE" "$HELM_CHART_DIR" \
        --namespace "$HELM_NAMESPACE" \
        --values "$HELM_VALUES" \
        --wait
    echo -e "${GREEN}✅ Helm upgrade complete.${RESET}"
fi
