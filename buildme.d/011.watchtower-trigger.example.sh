#!/bin/bash
# 011.watchtower-trigger.example.sh
# Calls the Watchtower HTTP API to trigger an immediate update check.
# Requires Watchtower running with --http-api-update and a token set.
# Docs: https://containrrr.dev/watchtower/http-api-mode/

WATCHTOWER_URL="http://your-host:8080/v1/update"
WATCHTOWER_TOKEN="your-watchtower-token"

if [[ "$SKIP_PUSH" == true ]]; then
    echo -e "${YELLOW}⏭️  Skipping Watchtower trigger (push was skipped).${RESET}"
    return 0
fi

echo -e "${BLUE}👁️  Triggering Watchtower update...${RESET}"
run_cmd curl -fsSL -X POST \
    -H "Authorization: Bearer ${WATCHTOWER_TOKEN}" \
    "$WATCHTOWER_URL"
echo -e "${GREEN}✅ Watchtower update triggered.${RESET}"
