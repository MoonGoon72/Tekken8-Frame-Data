#!/bin/sh

set -eu

: "${API_KEY:?Xcode Cloud API_KEY is missing}"
: "${SUPABASE_URL:?Xcode Cloud SUPABASE_URL is missing}"
: "${CI_WORKSPACE_PATH:?Xcode Cloud CI_WORKSPACE_PATH is missing}"

config_path="${CI_WORKSPACE_PATH}/Tekken8 Frame Data/TK8/Secrets.xcconfig"

umask 077
/usr/bin/printf 'API_KEY=%s\nSUPABASE_URL=%s\n' \
  "$API_KEY" \
  "$SUPABASE_URL" > "$config_path"

echo "Generated TK8/Secrets.xcconfig from Xcode Cloud environment variables."
