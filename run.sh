#!/bin/sh
set -e

if [ -z ${CLEANUP_BEFORE+x} ]; then CLEANUP_BEFORE=true; fi
if [ -z ${CLEANUP_AFTER+x} ]; then CLEANUP_AFTER=true; fi
if [ -z ${SLEEPTIME_BEFORE+x} ]; then SLEEPTIME_BEFORE=10; fi
if [ -z ${SLEEPTIME_AFTER+x} ]; then SLEEPTIME_AFTER=3600; fi
#if [ -z ${S3_STORAGE_CLASS+x} ]; then S3_STORAGE_CLASS=STANDARD_IA; fi
if [ -z ${S3_SSE+x} ]; then S3_SSE=AES256; fi
if [ -z ${S3_BUCKET+x} ]; then
  echo "Please define S3_BUCKET as backup target"
  exit 1
fi
S3_PREFIX=`date +%a`

# Mo
if [ $S3_PREFIX = 'Sun' ]; then
  # use STANDARD IA class only on Sunday because we keep them longer anyway
  S3_STORAGE_CLASS="STANDARD_IA"
else
  # use STANDARD class otherwise
  S3_STORAGE_CLASS="STANDARD"
fi

if [ -z ${GNUPG_KEY_FILE+x} ]; then
  unset GNUPG_KEY_ID
  echo "Please define GNUPG_KEY_FILE and GNUPG_KEY_ID for gpg encryption"
else
  echo "Importing gnupg public key file"
  gpg --import $GNUPG_KEY_FILE
  gpg --list-keys --with-fingerprint
fi

if [ $SLEEPTIME_BEFORE -gt 0 ]; then
  echo "Sleeping for $SLEEPTIME_BEFORE seconds..."
  sleep $SLEEPTIME_BEFORE
fi

mkdir -p /backup

if [ $CLEANUP_BEFORE ]; then
  echo "Cleaning up old backup files"
  find /backup/ -type f -delete
fi

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

echo "Syncing files to S3 Bucket $S3_BUCKET with class $S3_STORAGE_CLASS"

aws s3 sync . s3://$S3_BUCKET/$S3_PREFIX --storage-class $S3_STORAGE_CLASS --sse $S3_SSE

echo "Syncing finished"

if [ $CLEANUP_BEFORE ]; then
  echo "Cleaning up new backup files"
  find /backup/ -type f -delete
fi

if [ $SLEEPTIME_AFTER -gt 0 ]; then
  echo "Sleeping for $SLEEPTIME_AFTER seconds..."
  sleep $SLEEPTIME_AFTER
fi

echo "Exiting..."

exit 0
