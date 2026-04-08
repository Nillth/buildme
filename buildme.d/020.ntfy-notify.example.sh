#!/bin/bash
# 020.ntfy-notify.example.sh
# Sends a push notification via ntfy (self-hosted or ntfy.sh).
# Great for getting a phone notification when a build completes.
# Docs: https://docs.ntfy.sh/publish/

NTFY_URL="${NTFY_URL:-https://ntfy.sh/your-topic}"   # or https://your-ntfy.example.com/your-topic
NTFY_TOKEN="${NTFY_TOKEN:-}"                            # leave empty if topic is public
NTFY_PRIORITY="${NTFY_PRIORITY:-default}"                  # min, low, default, high, urgent

TITLE="${PROJECT_NAME} ${NEW_VERSION} deployed"
BODY=$(printf '%s\n' "${BUILT_REPOS[@]}")

AUTH_HEADER=()
[[ -n "$NTFY_TOKEN" ]] && AUTH_HEADER=(-H "Authorization: Bearer ${NTFY_TOKEN}")

echo -e "${BLUE}📲 Sending ntfy notification...${RESET}"
run_cmd curl -fsSL \
    -H "Title: ${TITLE}" \
    -H "Priority: ${NTFY_PRIORITY}" \
    -H "Tags: whale,white_check_mark" \
    "${AUTH_HEADER[@]}" \
    -d "$BODY" \
    "$NTFY_URL"
echo -e "${GREEN}✅ ntfy notification sent.${RESET}"
