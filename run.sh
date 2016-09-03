#!/bin/sh
set -e

if [ -z ${CLEANUP_BEFORE+x} ]; then CLEANUP_BEFORE=true; fi
if [ -z ${CLEANUP_AFTER+x} ]; then CLEANUP_AFTER=true; fi
if [ -z ${SLEEPTIME_BEFORE+x} ]; then SLEEPTIME_BEFORE=0; fi
if [ -z ${SLEEPTIME_AFTER+x} ]; then SLEEPTIME_AFTER=3600; fi

echo "Sleeping..."
sleep $SLEEPTIME_BEFORE

if [ -z ${GNUPG_KEY_FILE+x} ]; then
  unset GNUPG_KEY_ID
  echo "Please define GNUPG_KEY_FILE and GNUPG_KEY_ID for gpg encryption"
else
  echo "Importing gnupg public key file"
  gpg --import $GNUPG_KEY_FILE
  gpg --list-keys --with-fingerprint
fi

mkdir -p /backup

if [ $CLEANUP_BEFORE ]; then
  echo "Cleaning up old backup files"
  find /backup/ -type f -delete
else

cd /data

for f in *; do
  echo "Processing /data/$f"
  echo
  echo "Calculating orginal size:"
  du -s -h $f
  if [ -z ${GNUPG_KEY_ID+x} ]; then
    echo "Backing up $f as /backup/$f.tbz"
    tar -cvjf /backup/$f.tbz $f
  else
    echo "Backing up $f as /backup/$f.tbz.gpg"
    tar -cjvf - $f | gpg --encrypt -r $GNUPG_KEY_ID --trust-model always > /backup/$f.tbz.gpg
  fi
  sleep 1
  echo "Calculating backup size:"
  du -s -h /backup/$f.tbz*
  echo ""
done

cd /backup

echo "Syncing files to S3 Bucket $AWS_BACKUP_BUCKET"

aws s3 sync . s3://$AWS_BACKUP_BUCKET

if [ $CLEANUP_BEFORE ]; then
  echo "Cleaning up new backup files"
  find /backup/ -type f -delete
else

echo "Sleeping..."
sleep $SLEEPTIME_AFTER

exit 0
