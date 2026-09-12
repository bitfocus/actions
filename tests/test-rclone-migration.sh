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
  assert_contains '$/download-rclone' "$file"
  assert_contains './rclone rcat' "$file"
  assert_contains '--size "$FILE_SIZE"' "$file"
  assert_contains '--s3-no-head' "$file"
  assert_contains '--s3-no-check-bucket' "$file"
  assert_contains 's3-region:' "$file"
  assert_contains 'default: "eu-north-1"' "$file"
  assert_contains 'S3_REGION: ${{ inputs.s3-region }}' "$file"
  assert_contains 'RCLONE_CONFIG_REMOTE_REGION="$S3_REGION"' "$file"
  if [[ "$action" == upload ]]; then
    assert_contains "url=\${S3_HOST}/\${S3_BUCKET}/\${DESTINATION_FILENAME}" "$file"
    assert_contains 'echo "Upload file to ${S3_HOST}/${S3_BUCKET}/${DESTINATION_FILENAME}"' "$file"
  fi
  if grep -Eq '(^|[^[:alnum:]_-])mc([^[:alnum:]_-]|$)|download-minio-client|dl\.min\.io' "$file"; then
    printf 'legacy MinIO client reference in %s\n' "$file" >&2
    exit 1
  fi
done

assert_contains './rclone size --json' "$ROOT/upload-and-notify-for-branch/action.yaml"
assert_contains '.bytes' "$ROOT/upload-and-notify-for-branch/action.yaml"
assert_contains '$/upload-and-notify-for-branch' "$ROOT/upload-and-notify/action.yaml"
assert_contains 's3-region: ${{ inputs.s3-region }}' "$ROOT/upload-and-notify/action.yaml"
if rg -n --hidden -S 'uses: .*@main' "$ROOT" -g '!\.git' -g '!tests/*'; then
  printf 'main branch reference remains in nested action use\n' >&2
  exit 1
fi
