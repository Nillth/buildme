#!/usr/bin/bash
# install-wsl-ssh-agent.sh
# Usage:
#   bash install-wsl-ssh-agent.sh [--local-user USERNAME] [--npiperelay-path PATH]
# Examples:
#   bash install-wsl-ssh-agent.sh
#   sudo bash install-wsl-ssh-agent.sh --local-user marc
#   bash install-wsl-ssh-agent.sh --npiperelay-path /mnt/c/tools/npiperelay.exe
# curl -fsSL https://gist.githubusercontent.com/Nillth/c8bdbb660994cffd7b135f418965218b/raw/install-wsl-ssh-agent.sh | sudo bash -s -- --local-user marc

set -euo pipefail

# ---- helpers ----
_inf(){ printf '%s\n' "INFO: $*"; }
_warn(){ printf '%s\n' "WARN: $*" >&2; }
_die(){ printf '%s\n' "ERROR: $*" >&2; exit 1; }

_norm_ver(){ printf '%s' "$1" | sed -E 's/^v//; s/[^0-9.].*$//'; }

_extract_npiperelay_exe() {
  local zip="$1" dest="$2"
  local extraction_success=0
  
  if command -v unzip >/dev/null 2>&1; then
    if unzip -p "$zip" 'npiperelay.exe' > "$dest"; then
      extraction_success=1
    fi
  elif command -v bsdtar >/dev/null 2>&1; then
    if bsdtar -xOf "$zip" 'npiperelay.exe' > "$dest"; then
      extraction_success=1
    fi
  elif tar --version 2>/dev/null | grep -qi bsdtar; then
    if tar -xOf "$zip" 'npiperelay.exe' > "$dest"; then
      extraction_success=1
    fi
  elif command -v python3 >/dev/null 2>&1; then
    if python3 - "$zip" "$dest" <<'PY'
import sys, zipfile
zip_path, out_path = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zip_path, 'r') as zf, open(out_path, 'wb') as out:
    out.write(zf.read('npiperelay.exe'))
PY
    then
      extraction_success=1
    fi
  else
    echo "ERROR: need one of: unzip, bsdtar, (bsd)tar, or python3." >&2
    echo "Try: sudo apt-get install -y unzip   # or: sudo apt-get install -y libarchive-tools" >&2
  fi
  
  if [ "$extraction_success" -eq 1 ] && [ -f "$dest" ]; then
    chmod +x "$dest"
    return 0
  else
    echo "ERROR: Extraction failed - $dest was not created or extraction command failed" >&2
    return 1
  fi
}

ver_ge(){  # $1 >= $2 using sort -V
  [ -z "${2:-}" ] && return 0
  [ "$(printf '%s\n%s\n' "$(_norm_ver "$2")" "$(_norm_ver "$1")" | sort -V | tail -1)" = "$(_norm_ver "$1")" ]
}

npiperelay_current_ver(){
  local exe="$1"
  [ -x "$exe" ] || return 1
  local out
  out="$("$exe" -v 2>&1 || true)"
  printf '%s' "$(printf '%s' "$out" | grep -Eo 'v?[0-9]+(\.[0-9]+){1,2}' | head -n1)"
}

npiperelay_latest(){
  local repo="albertony/npiperelay" api tag dl
  api="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")" || return 1
  if command -v jq >/dev/null 2>&1; then
    tag="$(printf '%s' "$api" | jq -r '.tag_name')"
    dl="$(printf '%s' "$api" | jq -r '.assets[] | select(.name|test("windows_amd64\\.zip")) | .browser_download_url')"
  else
    tag="$(printf '%s' "$api" | grep -oE '"tag_name":[[:space:]]*"[^"]+"' | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')"
    dl="$(printf '%s' "$api" | grep -oE '"browser_download_url":[[:space:]]*"[^"]+"' \
          | grep -E 'windows_amd64\.zip' | sed -E 's/.*"browser_download_url":[[:space:]]*"([^"]+)".*/\1/' | head -n1)"
  fi
  [ -n "$tag" ] && [ -n "$dl" ] || return 1
  printf '%s %s\n' "$tag" "$dl"
}

download_npiperelay(){
  local url="$1" dest="$2"
  local tmpzip; tmpzip="$(mktemp --suffix=.zip)"
  
  if ! curl -fsSL "$url" -o "$tmpzip"; then
    echo "ERROR: Failed to download from $url" >&2
    rm -f "$tmpzip"
    return 1
  fi
  
  if ! _extract_npiperelay_exe "$tmpzip" "$dest"; then
    echo "ERROR: Failed to extract npiperelay.exe" >&2
    rm -f "$tmpzip"
    return 1
  fi
  
  rm -f "$tmpzip"
  return 0
}

ensure_ssh_profile_block(){
  local rc="$1" np_path="$2"
  [ -f "$rc" ] || touch "$rc"
  local START="# >>> WSL-SSH-AGENT BEGIN >>>"
  local END="# <<< WSL-SSH-AGENT END <<<"
  
  # remove existing managed block (if any)
  awk -v start="$START" -v end="$END" '
    $0==start {skip=1}
    skip && $0==end {skip=0; next}
    !skip {print}
  ' "$rc" > "${rc}.tmp"

  # write fresh block
  cat >> "${rc}.tmp" <<EOF
$START
export SSH_AUTH_SOCK="\$HOME/.ssh/agent.sock"

if [ ! -S "\$SSH_AUTH_SOCK" ]; then
  rm -f "\$SSH_AUTH_SOCK"
  if command -v socat >/dev/null 2>&1; then
    socat UNIX-LISTEN:"\$SSH_AUTH_SOCK",unlink-early,fork EXEC:"$np_path -ei -s //./pipe/openssh-ssh-agent",nofork &
    sleep 0.2
  else
    echo "WARN: socat not installed. Try: sudo apt-get install -y socat" >&2
  fi
fi
$END
EOF

  mv "${rc}.tmp" "$rc"
}

ensure_gpg_profile_block(){
  local rc="$1" np_path="$2"
  [ -f "$rc" ] || touch "$rc"
  local START="# >>> WSL-GPG-AGENT BEGIN >>>"
  local END="# <<< WSL-GPG-AGENT END <<<"
  
  # remove existing managed block (if any)
  awk -v start="$START" -v end="$END" '
    $0==start {skip=1}
    skip && $0==end {skip=0; next}
    !skip {print}
  ' "$rc" > "${rc}.tmp"

  # write fresh block
  cat >> "${rc}.tmp" <<EOF
$START
export GNUPGHOME="\$HOME/.gnupg"
mkdir -p "\$GNUPGHOME"

WINUSER=\$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')

if [ ! -S "\$GNUPGHOME/S.gpg-agent" ]; then
  rm -f "\$GNUPGHOME/S.gpg-agent"
  if command -v socat >/dev/null 2>&1 && [ -n "\$WINUSER" ]; then
    socat UNIX-LISTEN:"\$GNUPGHOME/S.gpg-agent",fork EXEC:"$np_path -ei -ep -a C:/Users/\$WINUSER/AppData/Local/gnupg/S.gpg-agent",nofork &
    sleep 0.2
  fi
fi
$END
EOF

  mv "${rc}.tmp" "$rc"
}

# -------------------------------------------------------------------
#                          main
# -------------------------------------------------------------------
main() {
  echo "installer version 1.1.0"

  # Parse arguments
  LOCAL_USER="${SUDO_USER:-$(whoami)}"
  NPIPERELAY_PATH=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --local-user)  LOCAL_USER="${2:-}"; shift 2 ;;
      --npiperelay-path) NPIPERELAY_PATH="${2:-}"; shift 2 ;;
      -h|--help)
        grep -E '^# ' "$0" | sed 's/^# //'; exit 0 ;;
      *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
  done

  # Resolve target user's home dir (portable across distros)
  if ! TARGET_HOME="$(getent passwd "$LOCAL_USER" | cut -d: -f6)"; then
    _die "local user '$LOCAL_USER' not found."
  fi

  _inf "Target user: $LOCAL_USER"
  _inf "Target home: $TARGET_HOME"

  # Set default npiperelay path if not specified
  DEFAULT_PATH="/mnt/c/npiperelay/npiperelay.exe"
  
  if [ -z "$NPIPERELAY_PATH" ]; then
    echo "Default npiperelay.exe location: $DEFAULT_PATH"
    if [ -t 0 ]; then
      read -rp "Enter custom path, or press Enter to accept default: " NPIPERELAY_PATH </dev/tty
    fi
    NPIPERELAY_PATH="${NPIPERELAY_PATH:-$DEFAULT_PATH}"
  fi
  
  echo "Using npiperelay path: $NPIPERELAY_PATH"

  # Make sure ~/.ssh exists for target user
  TARGET_SSH_DIR="$TARGET_HOME/.ssh"
  if [ ! -d "$TARGET_SSH_DIR" ]; then
    echo "Creating $TARGET_SSH_DIR directory..."
    install -d -m 700 -o "$LOCAL_USER" -g "$(id -gn "$LOCAL_USER")" "$TARGET_SSH_DIR"
  fi

  # Ensure destination directory exists
  mkdir -p "$(dirname "$NPIPERELAY_PATH")"

  # -------------------------------------------------------------------
  #           install/update npiperelay.exe (idempotent, latest)
  # -------------------------------------------------------------------
  latest_line="$(npiperelay_latest || true)"
  if [ -z "$latest_line" ]; then
    _warn "Could not fetch latest release info. Will only install if missing."
  fi

  latest_tag="${latest_line%% *}"
  latest_url="${latest_line#* }"

  if [ -f "$NPIPERELAY_PATH" ]; then
    _inf "Found existing npiperelay at $NPIPERELAY_PATH"
    cur_ver="$(npiperelay_current_ver "$NPIPERELAY_PATH" || true)"
    if [ -n "$latest_tag" ] && [ -n "$cur_ver" ] && ver_ge "$cur_ver" "$latest_tag"; then
      _inf "Installed version ($cur_ver) is up-to-date (latest: $latest_tag)."
    else
      if [ -n "$latest_url" ]; then
        _inf "Updating npiperelay ($cur_ver) -> $latest_tag"
        if download_npiperelay "$latest_url" "$NPIPERELAY_PATH"; then
          _inf "Update completed successfully"
        else
          _warn "Download failed, but continuing with profile setup..."
        fi
      else
        _warn "Latest URL unknown; keeping existing binary."
      fi
    fi
  else
    echo "npiperelay.exe not found at $NPIPERELAY_PATH, downloading..."
    if [ -n "$latest_url" ]; then
      if ! download_npiperelay "$latest_url" "$NPIPERELAY_PATH"; then
        _warn "Primary download failed, trying fallback..."
        curl -fsSL "https://github.com/albertony/npiperelay/releases/latest/download/npiperelay_windows_amd64.exe" -o "$NPIPERELAY_PATH"
        chmod +x "$NPIPERELAY_PATH"
      fi
    else
      _warn "No latest URL available for download."
    fi
  fi

  # -------------------------------------------------------------------
  #             profile snippet (idempotent)
  # -------------------------------------------------------------------
  TARGET_PROFILE="$TARGET_HOME/.profile"
  
  _inf "Setting up profile blocks in $TARGET_PROFILE"
  ensure_ssh_profile_block "$TARGET_PROFILE" "$NPIPERELAY_PATH"
  ensure_gpg_profile_block "$TARGET_PROFILE" "$NPIPERELAY_PATH"
  
  # Fix ownership if running as root
  if [ "$(id -u)" -eq 0 ]; then
    chown "$LOCAL_USER:$(id -gn "$LOCAL_USER")" "$TARGET_PROFILE"
  fi
  
  echo "Profile configuration has been ensured in $TARGET_PROFILE"

  # Optional: also update .bashrc / .zshrc for interactive shells
  if [ -n "${UPDATE_ALL_SHELLS:-}" ]; then
    if [ -f "$TARGET_HOME/.bashrc" ]; then
      ensure_ssh_profile_block "$TARGET_HOME/.bashrc" "$NPIPERELAY_PATH"
      ensure_gpg_profile_block "$TARGET_HOME/.bashrc" "$NPIPERELAY_PATH"
      [ "$(id -u)" -eq 0 ] && chown "$LOCAL_USER:$(id -gn "$LOCAL_USER")" "$TARGET_HOME/.bashrc"
    fi
    if [ -f "$TARGET_HOME/.zshrc" ]; then
      ensure_ssh_profile_block "$TARGET_HOME/.zshrc" "$NPIPERELAY_PATH"
      ensure_gpg_profile_block "$TARGET_HOME/.zshrc" "$NPIPERELAY_PATH"
      [ "$(id -u)" -eq 0 ] && chown "$LOCAL_USER:$(id -gn "$LOCAL_USER")" "$TARGET_HOME/.zshrc"
    fi
  fi

  # -------------------------------------------------------------------
  if [ ! -f "$NPIPERELAY_PATH" ]; then
    echo "NOTE: If npiperelay.exe download failed, you may need to manually download it to: $NPIPERELAY_PATH"
  fi

  echo "=========================================="
  echo "SCRIPT EXECUTION COMPLETED SUCCESSFULLY"
  echo "=========================================="
  echo "  Local user:      $LOCAL_USER"
  echo "  Profile updated: $TARGET_PROFILE"
  echo "  npiperelay path: $NPIPERELAY_PATH"
  echo ""
  echo "Run 'source $TARGET_PROFILE' or start a new shell to activate."
  echo "=========================================="
}

main "$@"