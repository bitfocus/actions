#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOWNLOADER="$ROOT/download-rclone/action.yaml"

assert_contains() {
  local needle=$1
  local file=$2
  grep -Fq -- "$needle" "$file" || {
    printf 'missing %q in %s\n' "$needle" "$file" >&2
    exit 1
  }
}

assert_contains 'RCLONE_VERSION: "1.75.1"' "$DOWNLOADER"
for target in linux-amd64 linux-arm64 osx-amd64 osx-arm64; do
  assert_contains "rclone-v\${RCLONE_VERSION}-${target}.zip" "$DOWNLOADER"
done
assert_contains "rclone-v\$env:RCLONE_VERSION-windows-amd64.zip" "$DOWNLOADER"
assert_contains 'sha256sum --check --status' "$DOWNLOADER"

for action in upload upload-artifact upload-and-notify-for-branch; do
  file="$ROOT/$action/action.yaml"
  assert_contains 'download-rclone@main' "$file"
  assert_contains './rclone copyto' "$file"
  if [[ "$action" == upload ]]; then
    assert_contains "url=\${S3_HOST}/\${S3_BUCKET}/\${DESTINATION_FILENAME}" "$file"
  fi
  if grep -Eq '(^|[^[:alnum:]_-])mc([^[:alnum:]_-]|$)|minio' "$file"; then
    printf 'legacy MinIO client reference in %s\n' "$file" >&2
    exit 1
  fi
done

assert_contains './rclone size --json' "$ROOT/upload-and-notify-for-branch/action.yaml"
assert_contains '.bytes' "$ROOT/upload-and-notify-for-branch/action.yaml"
