#!/bin/sh
# Runs before nginx starts (the official nginx image executes every
# /docker-entrypoint.d/*.sh). Regenerates config.js from the API_URL env var so
# the compiled Flutter web app can be repointed per-deployment without a rebuild.
set -e

CONFIG_FILE=/usr/share/nginx/html/config.js

if [ -n "$API_URL" ]; then
  printf 'window.h3xboardConfig = { apiUrl: "%s" };\n' "$API_URL" > "$CONFIG_FILE"
else
  printf 'window.h3xboardConfig = {};\n' > "$CONFIG_FILE"
fi
