#!/bin/bash
# 016.trivy-scan.example.sh
# Scans each built image for vulnerabilities using Trivy before considering
# the pipeline complete. Fails the hook (and stops subsequent hooks) if
# HIGH or CRITICAL vulnerabilities are found.
# Docs: https://aquasecurity.github.io/trivy/

SEVERITY="HIGH,CRITICAL"   # comma-separated: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
EXIT_ON_FAIL=true           # set false to report only, never block

if ! command -v trivy &>/dev/null; then
    echo -e "${YELLOW}⚠️  trivy not found in PATH. Skipping vulnerability scan.${RESET}"
    return 0
fi

SCAN_FAILED=false

for IMAGE_REPO in "${BUILT_REPOS[@]}"; do
    echo -e "${BLUE}🔍 Scanning ${IMAGE_REPO}:${NEW_VERSION} for ${SEVERITY} vulnerabilities...${RESET}"
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[dry-run] trivy image --exit-code 1 --severity ${SEVERITY} ${IMAGE_REPO}:${NEW_VERSION}${RESET}"
        continue
    fi
    if ! trivy image --exit-code 1 --severity "$SEVERITY" "${IMAGE_REPO}:${NEW_VERSION}"; then
        echo -e "${RED}❌ Vulnerabilities found in ${IMAGE_REPO}:${NEW_VERSION}${RESET}"
        SCAN_FAILED=true
    else
        echo -e "${GREEN}✅ ${IMAGE_REPO}:${NEW_VERSION} — no ${SEVERITY} vulnerabilities.${RESET}"
    fi
done

if [[ "$SCAN_FAILED" == true && "$EXIT_ON_FAIL" == true ]]; then
    echo -e "${RED}❌ Scan failed. Review vulnerabilities above.${RESET}"
    return 1
fi
