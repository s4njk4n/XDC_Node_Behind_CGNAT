#!/bin/bash

# =============================================
# xdc-behind-cgnat.sh - XDC Docker Peer Monitor
# =============================================

# ================== CONFIGURABLE VARIABLES ==================
THRESHOLD=15                    # Run peer.sh if peers drop below this
CHECK_INTERVAL_MINUTES=60       # How often to check the node (minutes)
FRIENDLY_NAME="My XDC Node"     # Friendly name shown in ntfy.sh alerts
NTFY_TOPIC="your-ntfy-topic"    # ntfy.sh topic (e.g. myxdcnodealerts)

# === DOCKER SETTINGS (MOST IMPORTANT - CHANGE THESE) ===
CONTAINER_NAME="xdcnetwork-mainnet-node"      # ←←← Run `docker ps` and put the exact container name here
BINARY_NAME="XDC"                             # Usually "XDC" (uppercase) in official XinFin images
IPC_PATH="/work/xdcchain/XDC.ipc"             # Standard IPC socket path in XDC Docker containers

PEER_SCRIPT_PATH="./peer.sh"                  # Path to your existing peer.sh
PAUSE_FLAG="/tmp/xdc-cgnat-paused.flag"
LOG_FILE="$HOME/xdc-cgnat-monitor.log"
# ===========================================================

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

get_peer_count() {
  # Quick check if container is running
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log "ERROR: Docker container '${CONTAINER_NAME}' is not running!"
    echo "0"
    return 1
  fi

  # Try admin.peers.length first (returns clean decimal number)
  local count
  count=$(docker exec -i "$CONTAINER_NAME" "$BINARY_NAME" \
    --exec 'admin.peers.length' attach "$IPC_PATH" 2>/dev/null | tr -d ' "\r\n')

  if [[ "$count" =~ ^[0-9]+$ ]]; then
    echo "$count"
    return 0
  fi

  # Fallback to net.peerCount (returns hex)
  count=$(docker exec -i "$CONTAINER_NAME" "$BINARY_NAME" \
    --exec 'net.peerCount' attach "$IPC_PATH" 2>/dev/null | tr -d ' "\r\n')

  if [[ "$count" == 0x* ]]; then
    printf "%d" "$count" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

log "=== XDC CGNAT Peer Monitor (DOCKER MODE) STARTED for '$FRIENDLY_NAME' ==="
log "Container: $CONTAINER_NAME | IPC: $IPC_PATH | Threshold: < $THRESHOLD peers | Interval: $CHECK_INTERVAL_MINUTES min"

while true; do
  # Respect pause flag
  if [ -f "$PAUSE_FLAG" ]; then
    log "Monitor is PAUSED (flag file exists). Sleeping 5 minutes..."
    sleep 300
    continue
  fi

  PEERS=$(get_peer_count)
  log "Current peer count: $PEERS"

  if [ "$PEERS" -lt "$THRESHOLD" ]; then
    log "Peer count ($PEERS) is below threshold ($THRESHOLD). Running peer.sh + sending alert..."

    # Run your existing peer.sh
    if [ -f "$PEER_SCRIPT_PATH" ] && [ -x "$PEER_SCRIPT_PATH" ]; then
      bash "$PEER_SCRIPT_PATH" >> "$LOG_FILE" 2>&1
      log "peer.sh execution finished."
    else
      log "ERROR: peer.sh not found or not executable at $PEER_SCRIPT_PATH"
    fi

    # Send ntfy.sh notification
    NOTIFY_MSG="${FRIENDLY_NAME} peers below threshold (${PEERS} < ${THRESHOLD}). Forcing peer addition via peer.sh."
    curl -s -X POST \
      -H "Title: XDC Peer Alert" \
      -H "Tags: xdc,warning,peer" \
      -H "Priority: high" \
      -d "$NOTIFY_MSG" \
      "https://ntfy.sh/${NTFY_TOPIC}" >/dev/null 2>&1 && \
      log "Notification sent to ntfy.sh/${NTFY_TOPIC}" || \
      log "WARNING: Failed to send ntfy.sh notification"

    sleep 300   # 5-minute grace period after forcing peers
  fi

  sleep $((CHECK_INTERVAL_MINUTES * 60))
done
