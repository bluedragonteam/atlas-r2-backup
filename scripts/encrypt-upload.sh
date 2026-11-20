#!/usr/bin/env bash
# Encrypt the dump for the given age recipients and upload it as daily/<date> (+ monthly/<month> once a month).
set -euo pipefail

: "${WORK:?}" "${AGE_RECIPIENTS:?}" "${BUCKET:?}"
endpoint="${ENDPOINT:-https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com}"
prefix="${PREFIX:-}"
day=$(date -u +%Y-%m-%d)
month=$(date -u +%Y-%m)

# Every recipient can decrypt on their own - keep a second key offline so losing one isn't fatal
args=()
for recipient in $(tr ',' ' ' <<< "$AGE_RECIPIENTS"); do
  args+=(-r "$recipient")
done
age "${args[@]}" -o "$WORK/backup.age" "$WORK/db.archive"
rm "$WORK/db.archive"

s3() { aws --endpoint-url "$endpoint" "$@"; }

key="${prefix}daily/${day}.archive.gz.age"
s3 s3 cp "$WORK/backup.age" "s3://${BUCKET}/${key}" --only-show-errors
size=$(stat -c %s "$WORK/backup.age")
echo "Uploaded ${key} (${size} bytes)"

if [ "${MONTHLY_COPY:-true}" = "true" ]; then
  monthly="${prefix}monthly/${month}.archive.gz.age"
  if ! s3 s3api head-object --bucket "$BUCKET" --key "$monthly" > /dev/null 2>&1; then
    s3 s3 cp "$WORK/backup.age" "s3://${BUCKET}/${monthly}" --only-show-errors
    echo "Also saved as ${monthly}"
  fi
fi

{
  echo "key=$key"
  echo "size=$size"
} >> "$GITHUB_OUTPUT"
