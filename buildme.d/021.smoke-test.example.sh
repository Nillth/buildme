#!/bin/bash
# 021.smoke-test.example.sh
# Spins up the built image, runs a test command inside it, then removes it.
# Catches packaging errors that only surface at runtime (missing files,
# bad entrypoint, broken env wiring, etc.) before anything is deployed.

SMOKE_IMAGE="${BUILT_REPOS[0]}:${NEW_VERSION}"
SMOKE_CMD="echo 'smoke ok'"   # replace with your app's self-check, e.g. "php -l index.php"
SMOKE_TIMEOUT=30              # seconds to wait for the command to complete
SMOKE_ENV=()                  # optional: ("-e" "FOO=bar" "-e" "BAZ=qux")

echo -e "${BLUE}🧪 Running smoke test on ${SMOKE_IMAGE}...${RESET}"

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[dry-run] $ENGINE run --rm --timeout ${SMOKE_TIMEOUT} ${SMOKE_IMAGE} ${SMOKE_CMD}${RESET}"
    return 0
fi

OUTPUT=$($ENGINE run --rm \
    --stop-timeout "$SMOKE_TIMEOUT" \
    "${SMOKE_ENV[@]}" \
    "$SMOKE_IMAGE" \
    /bin/sh -c "$SMOKE_CMD" 2>&1) && STATUS=0 || STATUS=$?

if [[ $STATUS -ne 0 ]]; then
    echo -e "${RED}❌ Smoke test failed (exit ${STATUS}):${RESET}"
    echo "$OUTPUT"
    return 1
fi

echo -e "${GREEN}✅ Smoke test passed.${RESET}"
[[ -n "$OUTPUT" ]] && echo "$OUTPUT"
