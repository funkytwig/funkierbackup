# funkierbackup

Incremental Backup Script with Promotion and Retention
**Overview**
This Bash backup script performs incremental backups of a source directory into a structured destination backup directory, using rsync with hard links to save disk space and speed up backups. It organizes backups into hourly, daily, monthly, and yearly snapshots, automatically promoting the latest backups at designated times. Old backups are pruned according to retention policies to manage storage efficiently.
Key Features

    Incremental backups: Uses rsync --link-dest to hard-link unchanged files from the previous backup, minimizing storage use.
    Timestamped backup directories: Backups are stored in a nested year/month/day/hour folder hierarchy with suffixes:

        _H for hourly backups
        _D for daily backups
        _M for monthly backups
        _Y for yearly backups

    Promotion of backups:
        Latest hourly backup from the previous day is promoted to daily.
        Latest daily backup from the previous month is promoted to monthly.
        Latest monthly backup from the previous year is promoted to yearly.

    Retention policy:
        Keeps last 24 hourly backups.
        Keeps last 32 daily backups.
        Keeps last 13 monthly backups.
        Keeps yearly backups indefinitely.

    Verbose timestamped logging to /var/log/backups.log.
    Designed to be run via cron at scheduled times for backup, promotion, and cleanup.

How It Works
1. Hourly Backup
    The script creates a backup directory named as:

    $DEST/YYYY/MM/DD/HH_H

    where:
        YYYY = year (e.g., 2025)
        MM = month (01–12)
        DD = day of month (01–31)
        HH = hour in 24-hour format (00–23)
        _H suffix marks it as an hourly backup.

    It creates a temporary directory (*.tmp) first to safely build the backup.
    Uses rsync with --link-dest pointing to the latest previous backup (hourly, daily, monthly, or yearly) to hard-link unchanged files, reducing space and time.
    Upon successful completion, the temporary directory is atomically renamed to the final directory.

2. Backup Promotion
Hourly to Daily: Runs daily just after midnight.
1. Finds the latest hourly backup from the previous day (the directory with _H suffix).
2. Renames it by replacing _H with _D, marking it as a daily backup.

Daily to Monthly: Runs monthly on the 1st day.
1. Finds the latest daily backup from the previous month (directories with _D suffix).
2. Renames it by replacing _D with _M, marking it as a monthly backup.

Monthly to Yearly: Runs yearly on January 1st.
2. Finds the latest monthly backup from the previous year (directories with _M suffix).
1. Renames it by replacing _M with _Y, marking it as a yearly backup.

Cleanup / Retention: The script deletes backups older than the retention window:
1. Deletes hourly backups older than the 24 newest.
2. Deletes daily backups older than the 32 newest.
3. Deletes monthly backups older than the 13 newest.
4. Yearly backups (_Y) are retained indefinitely.

4. Logging
    All script output and errors are redirected to /var/log/backups.log with timestamps for easy monitoring and troubleshooting.

Usage
Prerequisites
1. Bash shell (#!/bin/bash)
2. rsync installed and accessible in the environment.
3. Permissions to read the source directory and write to the destination.
4. Write permission for /var/log/backups.log.
5. Cron daemon for scheduling.

Configuration
Edit the script variables near the top:

SRC="/path/to/source"
DEST="/path/to/backup"

Set SRC to the directory you want to back up, and DEST to your backup root directory.
Running the Script

The script accepts optional commands for promotions and cleanup:

./backup.sh                  # Perform hourly backup + cleanup
./backup.sh promote_hourly_to_daily
./backup.sh promote_daily_to_monthly
./backup.sh promote_monthly_to_yearly
./backup.sh cleanup          # Run cleanup only

Example Cron Jobs

\# Hourly backup + cleanup at 5 minutes past each hour

5 * * * * /path/to/backup.sh

\# Promote hourly backups to daily at 00:10 daily

10 0 * * * /path/to/backup.sh promote_hourly_to_daily

\# Promote daily backups to monthly at 00:20 on the 1st of each month

20 0 1 * * /path/to/backup.sh promote_daily_to_monthly

\# Promote monthly backups to yearly at 00:30 on Jan 1st each year

30 0 1 1 * /path/to/backup.sh promote_monthly_to_yearly

Notes
1. Ensure the backup destination ($DEST) has sufficient disk space.
2. Script assumes backup runs on a single machine with a local or mounted destination.
3. Adjust retention periods in the script as needed.
4. Use logrotate or another log management tool to rotate /var/log/backups.log.
5. The promotion strategy ensures backups “roll up” cleanly from hourly to yearly without overlapping or losing data.
