#!/bin/bash
# 010.portainer-webhook.example.sh
# Triggers a Portainer stack or service webhook to pull and redeploy.
# Create a webhook in Portainer: Stacks → your stack → Webhook → Enable
# Docs: https://docs.portainer.io/user/docker/stacks/webhooks

PORTAINER_WEBHOOK_URL="https://your-portainer.example.com/api/stacks/webhooks/YOUR-WEBHOOK-UUID"

if [[ "$SKIP_PUSH" == true ]]; then
    echo -e "${YELLOW}⏭️  Skipping Portainer webhook (push was skipped).${RESET}"
    return 0
fi

echo -e "${BLUE}🐳 Triggering Portainer webhook...${RESET}"
run_cmd curl -fsSL -X POST "$PORTAINER_WEBHOOK_URL"
echo -e "${GREEN}✅ Portainer webhook triggered.${RESET}"
