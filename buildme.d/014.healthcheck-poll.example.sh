#!/bin/bash
# 014.healthcheck-poll.example.sh
# Polls a URL after deployment until it returns HTTP 200 or times out.
# Useful as a final gate to confirm the new image is serving traffic.

HEALTH_URL="https://your-app.example.com/health"
MAX_WAIT=120   # seconds
INTERVAL=5     # seconds between polls

if [[ "$SKIP_PUSH" == true ]]; then
    echo -e "${YELLOW}⏭️  Skipping health check (push was skipped).${RESET}"
    return 0
fi

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[dry-run] Would poll ${HEALTH_URL} for up to ${MAX_WAIT}s${RESET}"
    return 0
fi

echo -e "${BLUE}🩺 Polling ${HEALTH_URL} (timeout: ${MAX_WAIT}s)...${RESET}"
ELAPSED=0
until curl -fsSL --max-time 5 "$HEALTH_URL" &>/dev/null; do
    if (( ELAPSED >= MAX_WAIT )); then
        echo -e "${RED}❌ Health check timed out after ${MAX_WAIT}s.${RESET}"
        return 1
    fi
    echo -e "${YELLOW}   waiting... (${ELAPSED}s elapsed)${RESET}"
    sleep "$INTERVAL"
    ELAPSED=$(( ELAPSED + INTERVAL ))
done

echo -e "${GREEN}✅ Health check passed (${ELAPSED}s).${RESET}"
