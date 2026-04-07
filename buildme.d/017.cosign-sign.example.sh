#!/bin/bash
# 017.cosign-sign.example.sh
# Signs each pushed image with cosign (Sigstore) for supply chain security.
# Supports both keyless (Fulcio/OIDC) and key-based signing.
# Docs: https://docs.sigstore.dev/cosign/signing/overview/

SIGN_MODE="keyless"          # "keyless" or "key"
COSIGN_KEY_PATH=""           # required when SIGN_MODE=key, e.g. /secrets/cosign.key

if ! command -v cosign &>/dev/null; then
    echo -e "${YELLOW}⚠️  cosign not found in PATH. Skipping image signing.${RESET}"
    return 0
fi

if [[ "$SKIP_PUSH" == true ]]; then
    echo -e "${YELLOW}⏭️  Skipping signing (push was skipped — no digest in registry).${RESET}"
    return 0
fi

for IMAGE_REPO in "${BUILT_REPOS[@]}"; do
    echo -e "${BLUE}✍️  Signing ${IMAGE_REPO}:${NEW_VERSION}...${RESET}"
    if [[ "$SIGN_MODE" == "keyless" ]]; then
        run_cmd cosign sign --yes "${IMAGE_REPO}:${NEW_VERSION}"
    else
        if [[ -z "$COSIGN_KEY_PATH" || ! -f "$COSIGN_KEY_PATH" ]]; then
            echo -e "${RED}❌ COSIGN_KEY_PATH not set or file not found.${RESET}"
            return 1
        fi
        run_cmd cosign sign --key "$COSIGN_KEY_PATH" "${IMAGE_REPO}:${NEW_VERSION}"
    fi
    echo -e "${GREEN}✅ Signed ${IMAGE_REPO}:${NEW_VERSION}.${RESET}"
done
