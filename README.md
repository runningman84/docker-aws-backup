AWS Backup
============

[![](https://images.microbadger.com/badges/version/runningman84/aws-backup.svg)](https://hub.docker.com/r/runningman84/aws-backup "Click to view the image on Docker Hub")
[![](https://images.microbadger.com/badges/image/runningman84/aws-backup.svg)](https://hub.docker.com/r/runningman84/aws-backup "Click to view the image on Docker Hub")
[![](https://img.shields.io/docker/stars/runningman84/aws-backup.svg)](https://hub.docker.com/r/runningman84/aws-backup "Click to view the image on Docker Hub")
[![](https://img.shields.io/docker/pulls/runningman84/aws-backup.svg)](https://hub.docker.com/r/runningman84/aws-backup "Click to view the image on Docker Hub")

Introduction
----
This docker handles periodic backups to S3 using Alpine Linux.

It iterates through all folders in /data and creates  compressed archives. These archives can be encrypted using GPG. The idea to have this container running with the restart always function. The backup operation will be started afer the SLEEPTIME_BEFORE elapsed. It backs up all folders and sleeps until SLEEPTIME_AFTER. Once the SLEEPTIME_AFTER is over, the container will exit with status 0. The docker restart function will start it again.

Install
----

```sh
docker pull runningman84/aws-backup
```

Running
----

This is an example docker compose file for a daily backup of the caddy, cgate and grafana folders:

```yaml
version: "2"
services:
  backup:
    image: runningman84/aws-backup
    volumes:
        -   /data/docker/caddy:/data/caddy
        -   /data/docker/cgate:/data/cgate
        -   /data/docker/grafana:/data/grafana
        -   ./mypubkey.asc:/tmp/keyfile.asc
    environment:
      AWS_ACCESS_KEY_ID: "XXXXXXXXXXXXXXXXX"
      AWS_SECRET_ACCESS_KEY: "YYYYYYYY/ZZZZZZZZZZZZZZZZZZZZZ"
      AWS_REGION: "eu-west-1"
      S3_BUCKET: "my-personal-backup-ie"
      GNUPG_KEY_ID: KKKKKKKKKK
      GNUPG_KEY_FILE: /tmp/keyfile.asc
      SLEEPTIME_BEFORE: 10
      SLEEPTIME_AFTER: 86400
    restart: always
```

The container can be configured using these ENVIRONMENT variables:

Key | Description | Default
------------ | ------------- | -------------
AWS_ACCESS_KEY_ID | AWS API Access Key | none
AWS_SECRET_ACCESS_KEY | AWS API Secret Access Key | none
AWS_REGION | AWS region | none
CLEANUP_BEFORE | Cleanup backup folder before the backup operation | true
CLEANUP_AFTER | Cleanup backup folder after the backup operation | true
SLEEPTIME_BEFORE | The number of seconds to sleep before starting the backup | 10
SLEEPTIME_AFTER | The number of seconds to sleep after finished backup | 3600
S3_SSE | S3 Server side encryption method | AES256
S3_BUCKET | S3 bucket | none
GNUPG_KEY_ID | ID of public gpg key | none (disabled)
GNUPG_KEY_FILE | Filename of public gpg key | none (disabled)

These IAM policies are required to allow read and write of backups:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::my-personal-backup-ie"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": ["arn:aws:s3:::my-personal-backup-ie/*"]
    }
  ]
}
```
I would recommend to restrict the IAM policies and use S3 Versioning and Lifecycle rules. The file are stored with a prefix based an the locale's abbreviated weekday name (e.g. Sun, Mon, Thu, ... ). Files uploaded on Sunday are stored using the STANDARD_IA storage class. This class is cheaper but you will always pay a whole month. Uploads on all other weekdays are stored using the STANDARD class. The idea is to have 7 Lifecycle rules based on the Prefix. The Lifecycle rule for Sunday objects should store them for at least a month and the Lifecycle rule on other weekdays should store them only one week. This should be the most cost effective storage solution.
