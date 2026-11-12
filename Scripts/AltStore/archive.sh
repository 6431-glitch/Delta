#!/bin/bash
set -euo pipefail
set +x
umask 077
: "${RUNNER_TEMP:?}" "${EPSILON_CERTIFICATE_P12_BASE64:?}" "${EPSILON_CERTIFICATE_PASSWORD:?}" "${EPSILON_PROFILE_BASE64:?}" "${EPSILON_TEAM_ID:?}"
: "${GITHUB_RUN_NUMBER:?}"
[[ "$GITHUB_RUN_NUMBER" =~ ^[0-9]+$ ]] || { echo 'Invalid GitHub run number' >&2; exit 1; }
build_number=$((100000 + GITHUB_RUN_NUMBER))
work="$(mktemp -d "$RUNNER_TEMP/epsilon-signing.XXXXXX")"
keychain="$work/signing.keychain-db"
profile_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
profile_path=''
cleanup() {
  if [[ -n "$profile_path" ]]; then rm -f "$profile_path"; fi
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT
printf '%s' "$EPSILON_CERTIFICATE_P12_BASE64" | base64 -D > "$work/certificate.p12"
printf '%s' "$EPSILON_PROFILE_BASE64" | base64 -D > "$work/profile.mobileprovision"
security cms -D -i "$work/profile.mobileprovision" > "$work/profile.plist"
profile_values="$(python3 - "$work/profile.plist" "$EPSILON_TEAM_ID" <<'PY'
import plistlib,sys
with open(sys.argv[1], 'rb') as f: p=plistlib.load(f)
e=p['Entitlements']; team=sys.argv[2]
if e.get('application-identifier') != team + '.page.ducnguyen.Delta': raise SystemExit('Provisioning profile does not match Epsilon bundle ID and team')
if not p.get('ProvisionedDevices') and not p.get('ProvisionsAllDevices'): raise SystemExit('Profile must permit device distribution')
if 'CloudKit' not in e.get('com.apple.developer.icloud-services', []): raise SystemExit('Profile must include the CloudKit entitlement')
if 'iCloud.page.ducnguyen.Delta' not in e.get('com.apple.developer.icloud-container-identifiers', []): raise SystemExit('Profile must permit the Epsilon iCloud container')
print(p['UUID'])
print(p['Name'])
PY
)"
profile_uuid="$(printf '%s\n' "$profile_values" | sed -n '1p')"
profile_name="$(printf '%s\n' "$profile_values" | sed -n '2p')"
mkdir -p "$profile_dir"
profile_path="$profile_dir/$profile_uuid.mobileprovision"
if [[ -e "$profile_path" ]]; then echo 'Profile UUID already exists; refusing to overwrite.' >&2; profile_path=''; exit 1; fi
cp "$work/profile.mobileprovision" "$profile_path"
key_password="$(uuidgen)"
security create-keychain -p "$key_password" "$keychain"
security unlock-keychain -p "$key_password" "$keychain"
security import "$work/certificate.p12" -k "$keychain" -P "$EPSILON_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$key_password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain"
unset EPSILON_CERTIFICATE_P12_BASE64 EPSILON_CERTIFICATE_PASSWORD EPSILON_PROFILE_BASE64 key_password
python3 - "$work/ExportOptions.plist" "$EPSILON_TEAM_ID" "$profile_name" <<'PY'
import plistlib,sys
with open(sys.argv[1], 'wb') as f:
    plistlib.dump({'method':'release-testing','teamID':sys.argv[2],'signingStyle':'manual','provisioningProfiles':{'page.ducnguyen.Delta':sys.argv[3]}},f)
PY
xcodebuild -workspace Delta.xcworkspace -scheme Delta -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$work/Epsilon.xcarchive" \
  DEVELOPMENT_TEAM="$EPSILON_TEAM_ID" CODE_SIGN_STYLE=Manual \
  CURRENT_PROJECT_VERSION="$build_number" PROVISIONING_PROFILE_SPECIFIER="$profile_uuid" archive
xcodebuild -exportArchive -archivePath "$work/Epsilon.xcarchive" \
  -exportOptionsPlist "$work/ExportOptions.plist" -exportPath "$RUNNER_TEMP/epsilon-export"
