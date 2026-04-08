#!/usr/bin/env bash
# github-keys-install.sh
# Usage:
#   sudo bash github-keys-install.sh --github USER [--local-user USERNAME]
# Examples:
#   sudo bash github-keys-install.sh --github torvalds
#   sudo bash github-keys-install.sh --github octocat --local-user marc
# curl -fsSL https://gist.githubusercontent.com/Nillth/40029c26931788da98f703af49bee7a4/raw/524d2eb72c8d404c12eaed52fc36d780e2fa21e3/github-keys-install.sh | sudo bash -s -- --github nillth

set -euo pipefail

GH_USER=""
LOCAL_USER="${SUDO_USER:-$(whoami)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --github)      GH_USER="${2:-}"; shift 2 ;;
    --local-user)  LOCAL_USER="${2:-}"; shift 2 ;;
    -h|--help)
      grep -E '^# ' "$0" | sed 's/^# //'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$GH_USER" ]]; then
  echo "Error: --github <username> is required." >&2
  exit 2
fi

# Resolve target user's home dir (portable across distros)
if ! TARGET_HOME="$(getent passwd "$LOCAL_USER" | cut -d: -f6)"; then
  echo "Error: local user '$LOCAL_USER' not found." >&2
  exit 2
fi

SSH_DIR="$TARGET_HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

echo "→ Fetching keys for GitHub user: $GH_USER"
TMP_KEYS="$(mktemp)"
if ! curl -fsSL "https://github.com/${GH_USER}.keys" -o "$TMP_KEYS"; then
  echo "Error: failed to download GitHub keys for '$GH_USER'." >&2
  rm -f "$TMP_KEYS"; exit 1
fi

if [[ ! -s "$TMP_KEYS" ]]; then
  echo "Warning: no keys found for GitHub user '$GH_USER'." >&2
  rm -f "$TMP_KEYS"; exit 0
fi

echo "→ Ensuring $SSH_DIR exists for local user: $LOCAL_USER"
install -d -m 700 -o "$LOCAL_USER" -g "$(id -gn "$LOCAL_USER")" "$SSH_DIR"

echo "→ Merging keys into $AUTH_KEYS (de-duplicated)"
TMP_MERGE="$(mktemp)"
touch "$AUTH_KEYS"
chown "$LOCAL_USER:$(id -gn "$LOCAL_USER")" "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

# Combine, normalize whitespace, and de-duplicate
cat "$AUTH_KEYS" "$TMP_KEYS" \
  | awk '{$1=$1}1' \
  | grep -E '^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp(256|384|521)) ' \
  | sort -u > "$TMP_MERGE"

mv "$TMP_MERGE" "$AUTH_KEYS"
chown "$LOCAL_USER:$(id -gn "$LOCAL_USER")" "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

# SELinux relabel if available (harmless if not)
if command -v restorecon >/dev/null 2>&1; then
  restorecon -R "$SSH_DIR" || true
fi

# Enable PubkeyAuthentication in sshd
SSHD_MAIN="/etc/ssh/sshd_config"
SSHD_DROPIN_DIR="/etc/ssh/sshd_config.d"
DROPIN="$SSHD_DROPIN_DIR/99-pubkey.conf"

echo "→ Enabling PubkeyAuthentication in sshd"
if [[ -d "$SSHD_DROPIN_DIR" ]]; then
  umask 022
  cat > "$DROPIN" <<'EOF'
# Managed by github-keys-install.sh
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2
EOF
else
  # Fallback: edit main config in place (with backup)
  cp -n "$SSHD_MAIN" "${SSHD_MAIN}.bak" || true
  if grep -qE '^\s*#?\s*PubkeyAuthentication' "$SSHD_MAIN"; then
    sed -i -E 's/^\s*#?\s*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_MAIN"
  else
    printf "\nPubkeyAuthentication yes\n" >> "$SSHD_MAIN"
  fi
  if ! grep -qE '^\s*AuthorizedKeysFile' "$SSHD_MAIN"; then
    printf "AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2\n" >> "$SSHD_MAIN"
  fi
fi

# Validate config before reload
if ! sshd -t 2>/tmp/sshd_test.err; then
  echo "Error: sshd config test failed:" >&2
  cat /tmp/sshd_test.err >&2
  exit 1
fi
rm -f /tmp/sshd_test.err

echo "→ Reloading sshd"
if systemctl is-active --quiet ssh; then
  systemctl reload ssh
elif systemctl is-active --quiet sshd; then
  systemctl reload sshd
elif command -v service >/dev/null 2>&1; then
  service ssh reload 2>/dev/null || service sshd reload 2>/dev/null || true
fi

echo "✓ Done."
echo "  Local user:     $LOCAL_USER"
echo "  AuthorizedKeys: $AUTH_KEYS"
echo "  GitHub user:    $GH_USER"
