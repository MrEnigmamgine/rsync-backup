# rsync-backup

This project is a simple script that allows you to define jobs for rsync. 
It is a thin wrapper around rsync for defining repeatable backup jobs designed to be scheduled through crontab or systemd timers, though nothing stops you from running it manually.

I created this script because I was unable to find an existing solution that:
- didn't involve installing and learning a whole new application
- didn't make the assumption that I wanted to back up everything
- allowed me to define multiple sets of sources and destinations
- allowed me to back up to an SSH host

## Features
- No new dependancies or applications to install.
- The script itself is ~~hopefully~~ easy to read and understand.
- Makes use of rsync's `--link-dest` feature, which saves on space consumption by hard-linking unchanged files from the previous backup instead up storing a new copy.
    - This works even with jobs using SSH
- Since this is just a wrapper for rsync it is possible to pass options directly to rsync, giving you full control over rsync's behavior.


## Getting Started

### Before you get started
Please understand that this is one of my first ever bash scripts. As such it is very likely to contain stupid mistakes. **Trust it at your own risk.** That said... it's been working fine for me across multiple systems.

Additionally, there are some aspects of this solution that have not been implemented yet.
Namely I haven't yet bothered with how to restore a backup to a system.  This is unlikely to change anytime soon since I only use this to backup configuration files and I prefer to restore those manually.

### Installation:
Simply clone this repo and execute the `install.sh` script as root.

Or, if you prefer, you can install manually:
1. Download the `rsync-backup` script to somewhere sensible like `/usr/local/bin/` or `~/.local/bin`.
2. Create the directory `/etc/rsync-backup`

## Usage and Configuration:
### Config files
Before you can run rsync-backup you will need to define a job, which is done using a configuration file. In reality the config file is just a bash file that gets sourced by the main script, therefore it is possible for the "configuration file" to execute arbitrary code. **Be careful about which users can edit these files.**

The script by default looks for the file `config.conf` in `/etc/rsync-backup`. A commented example can be found in the `example-job` directory of this repo.

At a minimum it should define what needs backed up and to where with the following variables:
```bash
SOURCE="</the/absolute/path/to/backup>"
DEST_ROOT="</the/path/to/store/backups>"
```

Until you are sure that this script is going to behave how you expect it to, you should also prevent the script from making changes by including the following:
```bash
IS_DRY_RUN=true

## Note: Recognized boolean values include {true|on|1|yes|y}
##       Everything else evaluates false   
```

## Running rsync-backup
With the configuration file in place it is possible to have rsync-backup do work:
```bash
# Assuming /etc/rsync-backupconfig.conf
rsync-backup 

# Subdirectories of /etc/rsync-backup define named jobs
# For example, this will use config.conf in /etc/rsync-backup/some-name
rsync-backup --job some-name

# To help with integrating with scheduling services, you can specify the default job
# The following two commands are equivalent
rsync-backup 
rsync-backup --job default

# Using a non-standard directory, still assumes config.conf
rsync-backup --config-dir /path/to/config-dir

## Note:  You can use flag --dry-run instead of setting IS_DRY_RUN in the config. For example:
rsync-backup --dry-run
```

You can also use `-h` or `--help` to show usage options.

## Filtering rules
### Global filter files

By default, rsync-backup will also consume rsync filtering rules in the config directory, assuming they are named one of the following:
- `exclude.txt`
- `include.txt`
- `from.txt`

All files use standard `rsync` pattern syntax. Paths are interpreted relative to the `SOURCE` unless absolute paths are used (for `--files-from`).

If for some reason you would like to suppress this behavior, you can do so by adding the following to your `config.conf`:

```bash
USE_EXCLUDE_FILE=false
USE_INCLUDE_FILE=false
USE_FROM_FILE=false
```

- `exclude.txt` maps to `--exclude-from` and contains patterns to skip.
- `include.txt` maps to `--include-from` and contains patterns to explicitly include.
- `from.txt` maps to `--files-from` and defines an explicit list of files to transfer.

If you want to store these outside of the confuration directory (ie. to share filters across multiple jobs), you can also specify files of any name or path by setting the following:
```bash
INCLUDE_FILE=
EXCLUDE_FILE=
FROM_FILE=
```

### Per-directory filters

Per-directory filters can be enabled or disabled with `PER_DIR_FILTERS`. When enabled (default), the script tells `rsync` to respect `.rsync-filter` files found within any directory being backed up. These files define include/exclude rules that apply only to that directory and its children, allowing fine-grained control without modifying the global config.
```bash
PER_DIR_FILTERS=true
```
Each `.rsync-filter` file uses standard `rsync` filter rule syntax. Common examples:

* `- *.log` → exclude all `.log` files in that directory
* `+ important.log` → include a specific file
* `- cache/` → exclude a directory
* `+ */` → include all directories (often needed to allow recursion when selectively including files)

Rules are evaluated in order, and the first matching rule wins.

**Note about the from_file:**  
    This file uses rsync's `--files-from` flag, which changes the default behavior of rsync (see rsync(1)). Namely the `--recursive` flag gets unset, which is supposed to get unset to make transferring *only* the files you specify easer. However, rsync-backup adds it back. This behavior is hard coded, so if you want to change it you will need to comment out or delete line 168 in the script. ( `RSYNC_OPTS+=(-r)` )

## Backing up to or from an SSH host

To use SSH simply add something like the following to your `config.conf`
```bash
SOURCE="/etc"
DEST_ROOT="/mnt/backup/etc_backup/${HOSTNAME}"

USE_SSH=true
SSH_KEY="/root/.ssh/id_ed25519"
SSH_USER="root"
SSH_HOST="some-ssh-host"

# SSH_PORT=22               ## If using a different port
# SSH_HOST_IS_SOURCE=true   ## If the job should pull from the ssh host
```

In this example, the files being backed up will be uploaded to the ssh host.
Please note, that the value of `SSH_KEY` points to a keyfile that is not password protected in order to allow unattended logins to the remote system.

## Logging and retention

### Logging
Logging is controlled by `LOG_DIR`. When set, the script writes log output for each run into that directory. Ensure the directory exists and is writable by the user running the job (e.g., root if run via systemd or cron). 

Currently there isn't a built-in mechanism for clearing out old logs, so you will need to manage this directory externally to ensure it does not grow too large.

### Retention
Retention is controlled by `RETENTION_DAYS`. When set to a positive integer, the script will automatically delete backup snapshots older than the specified number of days. For example, `RETENTION_DAYS=30` keeps the last 30 days of backups and removes anything older during each run. 

### Typical configuration:
```bash
LOG_DIR="/var/log/rsync-backup"
RETENTION_DAYS=30
```
This results in per-run logs stored under /var/log/rsync-backup and automatic pruning of backups older than 30 days.