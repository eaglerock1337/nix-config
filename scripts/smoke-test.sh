#!/usr/bin/env bash
# smoke-test.sh — post-deploy reachability check for an HLC node
# Usage: scripts/smoke-test.sh <hostname> <ip>
# Exit non-zero on any failure with a descriptive message.

set -u

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <hostname> <ip>" >&2
  exit 2
fi

HOST="$1"
IP="$2"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$HOME/.ssh/known_hosts"

echo "==> smoke-test $HOST ($IP)"

# Step 1: purge stale host key (reflashed nodes generate new keys; without
# this, every smoke-test after a reflash fails the host-key check).
ssh-keygen -R "$IP" >/dev/null 2>&1 || true

# Step 2: reachability.
if ! ping -c1 -W2 "$IP" >/dev/null 2>&1; then
  echo "FAIL [step 2/5]: $IP unreachable via ping" >&2
  exit 1
fi
echo "  [1/5] ping ok"

# Step 3: non-PTY ssh as bob; runs `true` on the remote.
if ! ssh $SSH_OPTS "bob@$IP" true; then
  echo "FAIL [step 3/5]: ssh bob@$IP true failed (key auth or sshd unhealthy)" >&2
  exit 1
fi
echo "  [2/5] non-PTY ssh ok"

# Step 4: PTY ssh — confirms a real shell allocation completes within 10s.
# This is the gate that catches the prior-art ssh-hang regression.
if ! timeout 10 ssh -tt $SSH_OPTS "bob@$IP" 'echo "HELLO_$(hostname)" && exit' </dev/null >/dev/null 2>&1; then
  echo "FAIL [step 4/5]: PTY ssh did not complete within 10s (suspected shell-init hang)" >&2
  exit 1
fi
echo "  [3/5] PTY ssh ok"

# Step 5: passwordless sudo — required by `nixos-rebuild --use-remote-sudo`.
# stderr suppressed so a config-drift password prompt does not spam operator
# terminal; the exit code alone is the signal.
if ! ssh $SSH_OPTS "bob@$IP" 'sudo -n true' 2>/dev/null; then
  echo "FAIL [step 5/5]: sudo -n failed; --use-remote-sudo will not work (check WORKAROUNDS W-002)" >&2
  exit 1
fi
echo "  [4/5] passwordless sudo ok"

echo "  [5/5] all checks passed for $HOST"
exit 0
