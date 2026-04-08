#!/bin/bash

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# Colors for pretty output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[0;34m'
RESET='\033[0m'

# ──────────────────────────────────────────────────────────────
# Self-update URL — change this to your raw GitHub URL after publishing
UPDATE_URL="https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main/buildme.sh"

# ──────────────────────────────────────────────────────────────
# CLI argument parsing
SKIP_PUSH=false
BUMP_MAJOR=false
DRY_RUN=false
DO_UPDATE=false
DO_EXTENSIONS=false
FORCE_ENGINE=""
FILTER_SERVICES=()

usage() {
    echo "Usage: $0 [options] [service...]"
    echo "  --skip-push            Build images but do not push to registry"
    echo "  --dry-run              Print commands without executing them"
    echo "  --bump-major           Increment the static major version before building"
    echo "  --engine docker|podman Force a specific container engine"
    echo "  --update               Download and replace this script with the latest version"
    echo "  --extensions           Interactively browse and install hook examples from the repo"
    echo "  --help                 Show this help message"
    echo "  service...             Build only these services (multi-service mode only)"
    echo ""
    echo "Modes (auto-detected):"
    echo "  single-image  Root Dockerfile found → builds one image named after the project"
    echo "  multi-service No root Dockerfile → scans subdirs for Dockerfiles"
    echo ""
    echo "Registry info is auto-detected from 'git remote origin'."
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-push)   SKIP_PUSH=true ;;
        --dry-run)     DRY_RUN=true ;;
        --bump-major)  BUMP_MAJOR=true ;;
        --update)      DO_UPDATE=true ;;
        --extensions)  DO_EXTENSIONS=true ;;
        --engine)      shift; FORCE_ENGINE="$1" ;;
        --help|-h)     usage ;;
        --*)           echo -e "${RED}❌ Unknown option: $1${RESET}"; usage ;;
        *)             FILTER_SERVICES+=("$1") ;;
    esac
    shift
done

# ──────────────────────────────────────────────────────────────
# Self-update: download latest script and replace this file
if [[ "$DO_UPDATE" == true ]]; then
    SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    echo -e "${BLUE}🔄 Checking for updates from: ${UPDATE_URL}${RESET}"

    if [[ "$UPDATE_URL" == *"YOUR_ORG"* ]]; then
        echo -e "${RED}❌ UPDATE_URL has not been configured. Edit the UPDATE_URL variable at the top of this script.${RESET}"
        exit 1
    fi

    # Prefer curl, fall back to wget
    TMP=$(mktemp /tmp/buildme.XXXXXX.sh)
    if command -v curl &>/dev/null; then
        HTTP_STATUS=$(curl -fsSL --write-out "%{http_code}" -o "$TMP" "$UPDATE_URL" 2>/dev/null)
    elif command -v wget &>/dev/null; then
        wget -q -O "$TMP" "$UPDATE_URL" 2>/dev/null && HTTP_STATUS="200" || HTTP_STATUS="000"
    else
        echo -e "${RED}❌ Neither curl nor wget found. Cannot update.${RESET}"
        rm -f "$TMP"
        exit 1
    fi

    if [[ "$HTTP_STATUS" != "200" ]]; then
        echo -e "${RED}❌ Download failed (HTTP ${HTTP_STATUS}). No changes made.${RESET}"
        rm -f "$TMP"
        exit 1
    fi

    # Sanity check: must start with a bash shebang and contain our marker
    if ! head -1 "$TMP" | grep -q '^#!/.*bash' || ! grep -q 'DO_UPDATE' "$TMP"; then
        echo -e "${RED}❌ Downloaded file does not look like a valid buildme.sh. Aborting.${RESET}"
        rm -f "$TMP"
        exit 1
    fi

    chmod +x "$TMP"
    cp "$TMP" "$SELF"
    rm -f "$TMP"
    echo -e "${GREEN}✅ Updated successfully: ${SELF}${RESET}"
    exit 0
fi

# ──────────────────────────────────────────────────────────────
# Extensions: interactive hook installer
if [[ "$DO_EXTENSIONS" == true ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    HOOK_INSTALL_DIR="${SCRIPT_DIR}/buildme.d"

    if [[ "$UPDATE_URL" == *"YOUR_ORG"* ]]; then
        echo -e "${RED}❌ UPDATE_URL has not been configured. Cannot fetch extension list.${RESET}"
        exit 1
    fi

    # Derive GitHub API URL and raw base from UPDATE_URL
    # Expects: https://raw.githubusercontent.com/OWNER/REPO/BRANCH/buildme.sh
    if [[ "$UPDATE_URL" =~ raw\.githubusercontent\.com/([^/]+)/([^/]+)/([^/]+)/ ]]; then
        EXT_OWNER="${BASH_REMATCH[1]}"
        EXT_REPO="${BASH_REMATCH[2]}"
        EXT_BRANCH="${BASH_REMATCH[3]}"
        EXT_RAW_BASE="https://raw.githubusercontent.com/${EXT_OWNER}/${EXT_REPO}/${EXT_BRANCH}/buildme.d"
        EXT_API_URL="https://api.github.com/repos/${EXT_OWNER}/${EXT_REPO}/contents/buildme.d?ref=${EXT_BRANCH}"
    else
        echo -e "${RED}❌ UPDATE_URL must be a raw.githubusercontent.com URL to use --extensions.${RESET}"
        exit 1
    fi

    echo -e "${BLUE}🔍 Fetching available extensions from ${EXT_OWNER}/${EXT_REPO}...${RESET}"
    API_RESPONSE=$(curl -fsSL "$EXT_API_URL" 2>/dev/null) || {
        echo -e "${RED}❌ Failed to fetch extension list. Check your internet connection.${RESET}"
        exit 1
    }

    # Parse filenames — filter to *.example.sh, skip the generic template
    EXT_NAMES=()
    while IFS= read -r name; do
        [[ "$name" == "001.example.sh" ]] && continue
        EXT_NAMES+=("$name")
    done < <(echo "$API_RESPONSE" \
        | grep -o '"name": *"[^"]*\.example\.sh"' \
        | sed 's/"name": *"//;s/"$//' \
        | sort)

    if [[ ${#EXT_NAMES[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No extensions found in repository.${RESET}"
        exit 1
    fi

    # Determine the next auto-assign number: highest existing active hook + 10, rounded up to 10
    mkdir -p "$HOOK_INSTALL_DIR"
    NEXT_NUM=10
    HIGHEST=$(find "$HOOK_INSTALL_DIR" -maxdepth 1 -name '[0-9]*.sh' ! -name '*.example.sh' \
        | sed 's|.*/||;s/[^0-9].*//' | sort -n | tail -1)
    if [[ -n "$HIGHEST" && "$HIGHEST" -gt 0 ]]; then
        NEXT_NUM=$(( (HIGHEST / 10 + 1) * 10 ))
    fi

    # Helper: check if a base name is already installed (ignores the NNN. prefix)
    _ext_installed() {
        local base="$1"
        find "$HOOK_INSTALL_DIR" -maxdepth 1 \
            \( -name "*.${base}.sh" -o -name "*.${base}.example.sh" \) 2>/dev/null \
            | grep -q .
    }

    # Display numbered menu
    echo ""
    echo -e "${BLUE}Available extensions:${RESET}"
    echo ""
    for i in "${!EXT_NAMES[@]}"; do
        name="${EXT_NAMES[$i]}"
        base=$(echo "$name" | sed 's/^[0-9]*\.//;s/\.example\.sh$//')
        status=""
        _ext_installed "$base" && status=" ${GREEN}[installed]${RESET}"
        printf "  [%2d]  %-45s%b\n" "$((i+1))" "$base" "$status"
    done
    echo ""
    echo -e "Enter numbers to install (space or comma-separated), or ${GREEN}all${RESET}, or ${YELLOW}q${RESET} to quit:"
    read -r -p "> " SELECTION
    echo ""

    [[ "$SELECTION" == "q" || -z "$SELECTION" ]] && { echo -e "${YELLOW}Cancelled.${RESET}"; exit 0; }

    # Resolve selection to indices
    SELECTED_INDICES=()
    if [[ "$SELECTION" == "all" ]]; then
        for i in "${!EXT_NAMES[@]}"; do SELECTED_INDICES+=("$i"); done
    else
        IFS=', ' read -r -a TOKENS <<< "$SELECTION"
        for token in "${TOKENS[@]}"; do
            if [[ "$token" =~ ^[0-9]+$ ]] && (( token >= 1 && token <= ${#EXT_NAMES[@]} )); then
                SELECTED_INDICES+=("$((token-1))")
            else
                echo -e "${YELLOW}⚠️  Ignoring invalid selection: ${token}${RESET}"
            fi
        done
    fi

    if [[ ${#SELECTED_INDICES[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No valid extensions selected.${RESET}"
        exit 0
    fi

    for idx in "${SELECTED_INDICES[@]}"; do
        name="${EXT_NAMES[$idx]}"
        base=$(echo "$name" | sed 's/^[0-9]*\.//;s/\.example\.sh$//')
        url="${EXT_RAW_BASE}/${name}"

        if _ext_installed "$base"; then
            echo -e "${YELLOW}⏭️  ${base} already installed — skipping.${RESET}"
            continue
        fi

        NUM=$(printf '%03d' "$NEXT_NUM")
        NEXT_NUM=$((NEXT_NUM + 10))
        DEST_ACTIVE="${HOOK_INSTALL_DIR}/${NUM}.${base}.sh"
        DEST_EXAMPLE="${HOOK_INSTALL_DIR}/${NUM}.${base}.example.sh"

        echo -e "${BLUE}⬇️  Installing ${base}...${RESET}"
        if curl -fsSL -o "$DEST_ACTIVE" "$url" && cp "$DEST_ACTIVE" "$DEST_EXAMPLE"; then
            chmod +x "$DEST_ACTIVE"
            echo -e "${GREEN}✅ buildme.d/${NUM}.${base}.sh${RESET} (active)"
            echo -e "   ${BLUE}buildme.d/${NUM}.${base}.example.sh${RESET} (reference copy)"
        else
            echo -e "${RED}❌ Failed to download ${base}.${RESET}"
            rm -f "$DEST_ACTIVE" "$DEST_EXAMPLE"
        fi
    done

    echo ""
    echo -e "${BLUE}Hooks are active immediately. The .example.sh copy is your pristine reference.${RESET}"
    exit 0
fi

# Helper: run or echo a command depending on --dry-run
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[dry-run]${RESET} $*"
    else
        "$@"
    fi
}

# ──────────────────────────────────────────────────────────────
# Anchor to git root so the script works from any subdirectory
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$GIT_ROOT"
echo -e "${BLUE}📁 Working directory: ${GIT_ROOT}${RESET}"

# ──────────────────────────────────────────────────────────────
# Version generation: (static).(date:yyddd).(incremental)
BUILD_FILE="${GIT_ROOT}/.build"

if [[ -f "$BUILD_FILE" ]]; then
    source "$BUILD_FILE"
    STATIC_VERSION="${VERSION:-0}"
    CURRENT_DATE="${YYDDD:-00000}"
    CURRENT_INCREMENTAL="${INCREMENTAL:-0}"
    echo -e "${BLUE}📂 Read from .build: VERSION=${STATIC_VERSION}, YYDDD=${CURRENT_DATE}, INCREMENTAL=${CURRENT_INCREMENTAL}${RESET}"
else
    STATIC_VERSION="0"
    CURRENT_DATE="00000"
    CURRENT_INCREMENTAL="0"
    echo -e "${BLUE}📂 No .build file found, using defaults${RESET}"
fi

if [[ "$BUMP_MAJOR" == true ]]; then
    STATIC_VERSION=$((STATIC_VERSION + 1))
    echo -e "${BLUE}⬆️  Bumping major version to ${STATIC_VERSION}${RESET}"
fi

DATE_VERSION=$(date +%y%j)  # yyddd format (year + day of year)

if [[ "$BUMP_MAJOR" == true || "$DATE_VERSION" != "$CURRENT_DATE" ]]; then
    INCREMENTAL="1"
    if [[ "$BUMP_MAJOR" == true ]]; then
        echo -e "${BLUE}📅 Major version bumped, resetting incremental to 1${RESET}"
    else
        echo -e "${BLUE}📅 New date detected, resetting incremental to 1${RESET}"
    fi
else
    INCREMENTAL=$((CURRENT_INCREMENTAL + 1))
    echo -e "${BLUE}🔢 Incrementing version from ${CURRENT_INCREMENTAL} to ${INCREMENTAL}${RESET}"
fi

NEW_VERSION="${STATIC_VERSION}.${DATE_VERSION}.${INCREMENTAL}"

if [[ "$DRY_RUN" == false ]]; then
    cat > "$BUILD_FILE" <<EOF
VERSION=${STATIC_VERSION}
YYDDD=${DATE_VERSION}
INCREMENTAL=${INCREMENTAL}
EOF
fi

echo -e "${BLUE}📋 Previous version: ${STATIC_VERSION}.${CURRENT_DATE}.${CURRENT_INCREMENTAL}${RESET}"
echo -e "${BLUE}🆕 New version: ${NEW_VERSION}${RESET}"

# ──────────────────────────────────────────────────────────────
# Auto-detect registry/repo config from git remote
parse_git_remote() {
    local url="${1%.git}"  # strip trailing .git
    if [[ "$url" =~ ^https?://([^/]+)/([^/]+)/([^/]+)$ ]]; then
        GIT_SERVER="${BASH_REMATCH[1]}"
        GIT_OWNER="${BASH_REMATCH[2]}"
        PROJECT_NAME="${BASH_REMATCH[3]}"
    elif [[ "$url" =~ ^(git@|ssh://git@)([^:/]+)[:/]([^/]+)/(.+)$ ]]; then
        GIT_SERVER="${BASH_REMATCH[2]}"
        GIT_OWNER="${BASH_REMATCH[3]}"
        PROJECT_NAME="${BASH_REMATCH[4]}"
    else
        return 1
    fi
}

LOCAL_BUILD=false
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -n "$REMOTE_URL" ]] && parse_git_remote "$REMOTE_URL"; then
    echo -e "${GREEN}🔗 Registry detected from git remote: ${GIT_SERVER}/${GIT_OWNER}/${PROJECT_NAME}${RESET}"
else
    PROJECT_NAME=$(basename "$GIT_ROOT")
    GIT_SERVER=""
    GIT_OWNER=""
    LOCAL_BUILD=true
    echo -e "${YELLOW}⚠️  No git remote detected. Using directory name as project: ${PROJECT_NAME}${RESET}"
    echo -e "${YELLOW}⚠️  Local build — push will be skipped automatically.${RESET}"
fi

# ──────────────────────────────────────────────────────────────
# Build mode: single-image (root Dockerfile) vs multi-service (subdirs)
SINGLE_IMAGE=false
if [[ -f "Dockerfile" ]]; then
    SINGLE_IMAGE=true
    echo -e "${BLUE}🏗️  Mode: single-image (root Dockerfile found)${RESET}"
    if [[ ${#FILTER_SERVICES[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Service filters are ignored in single-image mode.${RESET}"
    fi
else
    echo -e "${BLUE}🏗️  Mode: multi-service (scanning subdirectories for Dockerfiles)${RESET}"
    ALL_SERVICES=()
    for d in */; do
        [[ -f "${d}Dockerfile" ]] && ALL_SERVICES+=("${d%/}")
    done
    if [[ ${#ALL_SERVICES[@]} -eq 0 ]]; then
        echo -e "${RED}❌ No Dockerfiles found (root or any subdirectory).${RESET}"
        exit 1
    fi
    if [[ ${#FILTER_SERVICES[@]} -gt 0 ]]; then
        SERVICES=()
        for svc in "${FILTER_SERVICES[@]}"; do
            if [[ " ${ALL_SERVICES[*]} " == *" ${svc} "* ]]; then
                SERVICES+=("$svc")
            else
                echo -e "${YELLOW}⚠️  Service '${svc}' not found. Available: ${ALL_SERVICES[*]}${RESET}"
            fi
        done
        if [[ ${#SERVICES[@]} -eq 0 ]]; then
            echo -e "${RED}❌ No valid services matched.${RESET}"; exit 1
        fi
    else
        SERVICES=("${ALL_SERVICES[@]}")
    fi
    echo -e "${BLUE}📦 Services to build: ${SERVICES[*]}${RESET}"
fi

# ──────────────────────────────────────────────────────────────
# Tool detection: prefer docker, fallback to podman (override with --engine)
if [[ -n "$FORCE_ENGINE" ]]; then
    if command -v "$FORCE_ENGINE" &>/dev/null; then
        ENGINE="$FORCE_ENGINE"
        echo -e "${GREEN}🧪 Using container engine (forced): ${ENGINE}${RESET}"
    else
        echo -e "${RED}❌ Forced engine '${FORCE_ENGINE}' not found in PATH.${RESET}"; exit 1
    fi
elif command -v docker &>/dev/null; then
    ENGINE="docker"
    echo -e "${GREEN}🧪 Using container engine: docker${RESET}"
elif command -v podman &>/dev/null; then
    ENGINE="podman"
    echo -e "${YELLOW}⚠️  Docker not found. Using Podman instead.${RESET}"
else
    echo -e "${RED}❌ Neither docker nor podman found in PATH.${RESET}"
    exit 1
fi

# ──────────────────────────────────────────────────────────────
# Podman-specific: userns and SELinux detection
USERNS_FLAG=""
MOUNT_OPTS=""
if [[ "$ENGINE" == "podman" ]]; then
    if echo 'FROM scratch' | podman build --userns=keep-id -t test-userns -f - . &>/dev/null; then
        USERNS_FLAG="--userns=keep-id"
        echo -e "${GREEN}✅ Podman build supports userns=keep-id${RESET}"
    else
        USERNS_FLAG="--userns=auto"
        echo -e "${YELLOW}⚠️  Podman build does NOT support keep-id — falling back to userns=auto${RESET}"
    fi
    podman rmi test-userns &>/dev/null || true

    if command -v getenforce &>/dev/null && [[ "$(getenforce 2>/dev/null)" == "Enforcing" ]]; then
        MOUNT_OPTS=":z"
        echo -e "${GREEN}🔐 SELinux enforcing — using ':z' relabel on mounts${RESET}"
    else
        echo -e "${YELLOW}⚠️  SELinux not enforcing or not found${RESET}"
    fi
fi

# ──────────────────────────────────────────────────────────────
# Build
BUILT_REPOS=()

if [[ "$SINGLE_IMAGE" == true ]]; then
    if [[ "$LOCAL_BUILD" == true ]]; then
        IMAGE_REPO="${PROJECT_NAME,,}"
    else
        IMAGE_REPO="${GIT_SERVER}/${GIT_OWNER}/${PROJECT_NAME}"
        IMAGE_REPO="${IMAGE_REPO,,}"
    fi
    echo -e "${GREEN}🚀 Building ${PROJECT_NAME}...${RESET}"
    run_cmd $ENGINE build $USERNS_FLAG \
        -t "${IMAGE_REPO}:latest" \
        -t "${IMAGE_REPO}:${NEW_VERSION}" \
        .
    echo -e "Tags: ${GREEN}${IMAGE_REPO}:latest${RESET}, ${BLUE}${IMAGE_REPO}:${NEW_VERSION}${RESET}"
    echo -e "${GREEN}✅ Build completed.${RESET}"
    BUILT_REPOS+=("$IMAGE_REPO")
else
    for SERVICE in "${SERVICES[@]}"; do
        if [[ "$LOCAL_BUILD" == true ]]; then
            IMAGE_REPO="${PROJECT_NAME,,}-${SERVICE,,}"
        else
            IMAGE_REPO="${GIT_SERVER}/${GIT_OWNER}/${PROJECT_NAME}-${SERVICE}"
            IMAGE_REPO="${IMAGE_REPO,,}"
        fi
        echo -e "${GREEN}🚀 Building ${SERVICE}...${RESET}"
        run_cmd $ENGINE build $USERNS_FLAG \
            -t "${IMAGE_REPO}:latest" \
            -t "${IMAGE_REPO}:${NEW_VERSION}" \
            "./${SERVICE}"
        echo -e "Tags: ${GREEN}${IMAGE_REPO}:latest${RESET}, ${BLUE}${IMAGE_REPO}:${NEW_VERSION}${RESET}"
        echo -e "${GREEN}✅ ${SERVICE} build completed.${RESET}"
        BUILT_REPOS+=("$IMAGE_REPO")
    done
fi

# ──────────────────────────────────────────────────────────────
# Push images
if [[ "$LOCAL_BUILD" == true && "$SKIP_PUSH" == false ]]; then
    SKIP_PUSH=true
    SKIP_PUSH_REASON="local build — no remote registry"
elif [[ "$SKIP_PUSH" == true ]]; then
    SKIP_PUSH_REASON="--skip-push"
fi
if [[ "$SKIP_PUSH" == true ]]; then
    echo -e "${YELLOW}⏭️  Skipping push (${SKIP_PUSH_REASON}).${RESET}"
else
    for IMAGE_REPO in "${BUILT_REPOS[@]}"; do
        echo -e "${GREEN}📤 Pushing ${IMAGE_REPO}...${RESET}"
        run_cmd $ENGINE push "${IMAGE_REPO}:${NEW_VERSION}"
        run_cmd $ENGINE push "${IMAGE_REPO}:latest"
    done
    if [[ "$DRY_RUN" == false ]]; then
        echo -e "${GREEN}✅ All images pushed successfully.${RESET}"
    fi
fi

# ──────────────────────────────────────────────────────────────
# Post-build hooks
# Drop any *.sh files into a buildme.d/ directory next to this script.
# They are sourced in lexical order (001-first, 002-second, etc.).
# Each hook inherits all variables: NEW_VERSION, BUILT_REPOS, ENGINE,
# SKIP_PUSH, DRY_RUN, GIT_SERVER, GIT_OWNER, PROJECT_NAME,
# GIT_ROOT, and the run_cmd helper.
# Use 'return' (not 'exit') to bail out of an individual hook early.
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/buildme.d"
if [[ -d "$HOOK_DIR" ]]; then
    HOOK_FILES=()
    while IFS= read -r -d '' f; do
        HOOK_FILES+=("$f")
    done < <(find "$HOOK_DIR" -maxdepth 1 -name '*.sh' ! -name '*.example.sh' -print0 | sort -z)

    if [[ ${#HOOK_FILES[@]} -gt 0 ]]; then
        echo -e "${BLUE}🪝 Running ${#HOOK_FILES[@]} post-build hook(s) from buildme.d/${RESET}"
        for HOOK_FILE in "${HOOK_FILES[@]}"; do
            echo -e "${BLUE}   ↳ $(basename "$HOOK_FILE")${RESET}"
            # shellcheck source=/dev/null
            source "$HOOK_FILE"
        done
    fi
fi