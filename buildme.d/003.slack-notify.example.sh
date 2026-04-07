#!/bin/bash
# 003.slack-notify.example.sh
# Posts a build completion message to a Slack channel via Incoming Webhook.
# Docs: https://api.slack.com/messaging/webhooks

SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
SLACK_CHANNEL="#deployments"   # informational only, set in Slack app config
SLACK_USERNAME="buildme"

IMAGE_LIST=$(printf '`%s`\n' "${BUILT_REPOS[@]}")

PAYLOAD=$(cat <<EOF
{
  "username": "${SLACK_USERNAME}",
  "icon_emoji": ":whale:",
  "text": ":white_check_mark: *${PROJECT_NAME}* \`${NEW_VERSION}\` built and pushed.\n${IMAGE_LIST}"
}
EOF
)

echo -e "${BLUE}💬 Notifying Slack...${RESET}"
run_cmd curl -fsSL -X POST \
    -H 'Content-type: application/json' \
    --data "$PAYLOAD" \
    "$SLACK_WEBHOOK_URL"
echo -e "${GREEN}✅ Slack notified.${RESET}"
