#!/bin/bash
# 005.discord-notify.example.sh
# Posts a build completion message to a Discord channel via Webhook.
# Docs: https://discord.com/developers/docs/resources/webhook

DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-https://discord.com/api/webhooks/YOUR/WEBHOOK}"

IMAGE_LIST=$(printf '• `%s`\n' "${BUILT_REPOS[@]}")

PAYLOAD=$(cat <<EOF
{
  "username": "buildme",
  "avatar_url": "https://www.docker.com/wp-content/uploads/2022/03/vertical-logo-monochromatic.png",
  "embeds": [{
    "title": "✅ ${PROJECT_NAME} built and pushed",
    "color": 3066993,
    "fields": [
      { "name": "Version", "value": "\`${NEW_VERSION}\`", "inline": true },
      { "name": "Images", "value": "${IMAGE_LIST}", "inline": false }
    ]
  }]
}
EOF
)

echo -e "${BLUE}💬 Notifying Discord...${RESET}"
run_cmd curl -fsSL -X POST \
    -H 'Content-type: application/json' \
    --data "$PAYLOAD" \
    "$DISCORD_WEBHOOK_URL"
echo -e "${GREEN}✅ Discord notified.${RESET}"
