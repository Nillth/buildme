#!/bin/bash
# 027.gotify-notify.example.sh
# Sends a push notification via Gotify (self-hosted).
# Docs: https://gotify.net/docs/pushmsg

GOTIFY_URL="${GOTIFY_URL:-https://gotify.example.com}"  # base URL of your Gotify server (no trailing slash)
GOTIFY_TOKEN="${GOTIFY_TOKEN:-your-app-token}"            # application token from the Gotify UI
GOTIFY_PRIORITY="${GOTIFY_PRIORITY:-5}"                      # 1 (min) – 10 (max); ≥8 triggers urgent/sound on clients

TITLE="${PROJECT_NAME} ${NEW_VERSION} built"
BODY=$(printf '%s\n' "${BUILT_REPOS[@]}")

echo -e "${BLUE}📲 Sending Gotify notification...${RESET}"
run_cmd curl -fsSL \
    -X POST \
    -H "Content-Type: application/json" \
    -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
    -d "$(printf '{"title":"%s","message":"%s","priority":%s}' \
            "$TITLE" "$BODY" "$GOTIFY_PRIORITY")" \
    "${GOTIFY_URL}/message"
echo -e "${GREEN}✅ Gotify notification sent.${RESET}"
