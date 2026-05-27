#!/bin/bash
# xdc-behind-cgnat-pause.sh
# Creates the pause flag so the main monitor skips queries and actions

PAUSE_FLAG="/tmp/xdc-cgnat-paused.flag"

touch "$PAUSE_FLAG"
echo "✅ XDC CGNAT Peer Monitor has been PAUSED."
echo "   Flag file: $PAUSE_FLAG"
echo "   Run ./xdc-behind-cgnat-restart.sh to resume monitoring."
