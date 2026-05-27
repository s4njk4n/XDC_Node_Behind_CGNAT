#!/bin/bash
# xdc-behind-cgnat-restart.sh
# Deletes the pause flag so the main monitor resumes normal operation

PAUSE_FLAG="/tmp/xdc-cgnat-paused.flag"

if [ -f "$PAUSE_FLAG" ]; then
  rm -f "$PAUSE_FLAG"
  echo "✅ XDC CGNAT Peer Monitor has been RESUMED."
  echo "   The monitor will resume querying the node on its next cycle."
else
  echo "Monitor was not paused (no flag file found)."
fi
