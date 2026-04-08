#!/bin/bash
# 004.teams-notify.example.sh
# Posts a build completion card to a Microsoft Teams channel via Incoming Webhook.
# Docs: https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook

TEAMS_WEBHOOK_URL="${TEAMS_WEBHOOK_URL:-https://outlook.office.com/webhook/YOUR/WEBHOOK/URL}"

IMAGE_LIST=$(printf '<li>%s</li>' "${BUILT_REPOS[@]}")

PAYLOAD=$(cat <<EOF
{
  "@type": "MessageCard",
  "@context": "http://schema.org/extensions",
  "themeColor": "0076D7",
  "summary": "${PROJECT_NAME} ${NEW_VERSION} deployed",
  "sections": [{
    "activityTitle": "🐳 ${PROJECT_NAME} \`${NEW_VERSION}\` built and pushed",
    "activitySubtitle": "Images: <ul>${IMAGE_LIST}</ul>",
    "markdown": true
  }]
}
EOF
)

echo -e "${BLUE}💬 Notifying Microsoft Teams...${RESET}"
run_cmd curl -fsSL -X POST \
    -H 'Content-type: application/json' \
    --data "$PAYLOAD" \
    "$TEAMS_WEBHOOK_URL"
echo -e "${GREEN}✅ Teams notified.${RESET}"
