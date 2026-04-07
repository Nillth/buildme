#!/bin/bash
# 025.coolify-webhook.example.sh
# Triggers a Coolify deployment webhook after a successful push.
# Create the webhook in Coolify: Application → Webhooks → Deploy Webhook
# Docs: https://coolify.io/docs/webhooks

COOLIFY_WEBHOOK_URL="https://your-coolify.example.com/api/v1/deploy?uuid=YOUR-APP-UUID&force=false"
COOLIFY_TOKEN="${COOLIFY_TOKEN:-}"   # env var: COOLIFY_TOKEN (from Coolify → Security → API tokens)

if [[ -z "$COOLIFY_TOKEN" ]]; then
    echo -e "${YELLOW}⚠️  COOLIFY_TOKEN not set. Skipping Coolify deploy.${RESET}"
    return 0
fi

if [[ "$SKIP_PUSH" == true ]]; then
    echo -e "${YELLOW}⏭️  Skipping Coolify deploy (push was skipped).${RESET}"
    return 0
fi

echo -e "${BLUE}❄️  Triggering Coolify deployment...${RESET}"
run_cmd curl -fsSL -X GET \
    -H "Authorization: Bearer ${COOLIFY_TOKEN}" \
    "$COOLIFY_WEBHOOK_URL"
echo -e "${GREEN}✅ Coolify deployment triggered.${RESET}"
