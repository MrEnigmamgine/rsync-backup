#!/usr/bin/env bash

mkdir -p /etc/rsync-backup

cp -v ./rsync-backup /usr/local/bin/
#cp ./rsync-backup.service /etc/systemd/system/
#cp ./rsync-backup.timer /etc/systemd/system/
#systemctl daemon-reload

