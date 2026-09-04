#!/bin/sh

set -eu

: "${API_KEY:?Xcode Cloud API_KEY is missing}"
: "${SUPABASE_URL:?Xcode Cloud SUPABASE_URL is missing}"
: "${FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64:?Xcode Cloud FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64 is missing}"
: "${CI_PRIMARY_REPOSITORY_PATH:?Xcode Cloud CI_PRIMARY_REPOSITORY_PATH is missing}"

fail() {
  echo "$1" >&2
  exit 1
}

validate_api_key() {
  case "$API_KEY" in
    sb_publishable_*)
      return
      ;;
    sb_secret_*)
      fail "Xcode Cloud API_KEY must not be a Supabase secret key."
      ;;
    *.*.*)
      jwt_payload="$(printf '%s' "$API_KEY" | awk -F. 'NF == 3 { print $2 }')"
      [ -n "$jwt_payload" ] || fail "Xcode Cloud API_KEY is not a valid Supabase API key."

      case $((${#jwt_payload} % 4)) in
        0) ;;
        2) jwt_payload="${jwt_payload}==" ;;
        3) jwt_payload="${jwt_payload}=" ;;
        *) fail "Xcode Cloud API_KEY is not a valid legacy JWT API key." ;;
      esac

      jwt_role="$(printf '%s' "$jwt_payload" | tr '_-' '/+' | base64 -D 2>/dev/null | plutil -extract role raw - 2>/dev/null || true)"
      [ "$jwt_role" = "anon" ] || fail "Xcode Cloud API_KEY must be a publishable or legacy anon key."
      ;;
    *)
      fail "Xcode Cloud API_KEY must be a publishable or legacy anon key."
      ;;
  esac
}

validate_api_key

config_directory="${CI_PRIMARY_REPOSITORY_PATH}/Tekken8 Frame Data/TK8"
config_path="${config_directory}/Secrets.xcconfig"
firebase_config_path="${config_directory}/GoogleService-Info.plist"
[ -d "$config_directory" ] || fail "TK8 configuration directory is missing."

umask 077
temporary_config="$(mktemp "${config_directory}/Secrets.xcconfig.XXXXXX")"
temporary_firebase_config="$(mktemp "${config_directory}/GoogleService-Info.plist.XXXXXX")"
cleanup() {
  [ -z "${temporary_config:-}" ] || rm -f "$temporary_config"
  [ -z "${temporary_firebase_config:-}" ] || rm -f "$temporary_firebase_config"
}
trap cleanup EXIT

chmod 600 "$temporary_config"
/usr/bin/printf 'API_KEY=%s\nSUPABASE_URL=%s\n' \
  "$API_KEY" \
  "$SUPABASE_URL" > "$temporary_config"
mv -f "$temporary_config" "$config_path"
temporary_config=""

if ! /usr/bin/printf '%s' "$FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64" | /usr/bin/base64 -D > "$temporary_firebase_config"; then
  fail "Xcode Cloud FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64 is not valid Base64."
fi

if ! /usr/bin/plutil -lint "$temporary_firebase_config" >/dev/null; then
  fail "Decoded Firebase GoogleService-Info.plist is invalid."
fi

firebase_bundle_id="$(/usr/bin/plutil -extract BUNDLE_ID raw "$temporary_firebase_config" 2>/dev/null || true)"
[ "$firebase_bundle_id" = "com.moongoon.TK8" ] || fail "Firebase GoogleService-Info.plist has an unexpected BUNDLE_ID."

chmod 600 "$temporary_firebase_config"
mv -f "$temporary_firebase_config" "$firebase_config_path"
temporary_firebase_config=""

echo "Generated TK8 build configuration from Xcode Cloud environment variables."
