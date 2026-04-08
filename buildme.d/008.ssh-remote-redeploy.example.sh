#!/bin/bash
# 008.ssh-remote-redeploy.example.sh
# SSHes into a remote host and runs docker/podman pull + restart.
# Requires passwordless SSH key auth to the target host.

REMOTE_HOST="${REMOTE_HOST:-user@your-server.example.com}"
REMOTE_COMPOSE_DIR="${REMOTE_COMPOSE_DIR:-/opt/stacks/${PROJECT_NAME}}"

if [[ "$SKIP_PUSH" == true ]]; then
    echo -e "${YELLOW}⏭️  Skipping remote redeploy (push was skipped).${RESET}"
    return 0
fi

echo -e "${BLUE}🖥️  Redeploying on ${REMOTE_HOST}...${RESET}"
run_cmd ssh -o BatchMode=yes "$REMOTE_HOST" bash <<REMOTE
    set -euo pipefail
    cd "${REMOTE_COMPOSE_DIR}"
    docker compose pull
    docker compose up -d --remove-orphans
REMOTE
echo -e "${GREEN}✅ Remote redeploy complete.${RESET}"
