
# 🔷 BackupWatch Documentation
---
## Introduction

**BackupWatch** is a web-based application designed to monitor the status of backups through emails. The application checks incoming emails for specific keywords that indicate the success or failure of a backup operation. Based on the keywords found, BackupWatch updates the status of each backup, helping administrators easily identify which backups have succeeded or failed.


## License and Open-Source Nature

BackupWatch is an open-source project licensed under the **Apache-2.0 license**. You are free to use, modify, and distribute the software under the terms of this license.

### Key Points:
- **Transparency**: Open-source nature ensures transparency and security.
- **Collaboration**: Encourages community contributions and collaboration.
- **Customizability**: Fully customizable according to your needs.


## Features

BackupWatch offers a comprehensive set of features to monitor and manage backups effectively:

- **Backup Monitoring**: Automatically checks emails for backup success or failure based on user-defined keywords.
- **Real-time Status Updates**: Displays current backup status with color-coded indicators.
- **Automatic Refresh**: Periodically refreshes backup status based on a configurable interval.
- **Account Management**: Allows administrators to manage user accounts.
- **Customizable Configuration**: Adjust settings such as email server details, port number, and refresh intervals.
- **Version Updates**: Check for and install new application versions easily.
- **Dark and Light Mode**: Toggle between dark and light themes.


## User Roles

BackupWatch categorizes users into three roles: **Admin**, **Moderator**, and **Guest**. Each role has different permissions and access levels.

### Admin
Admins have full access to all features, including:
- **Manage Backups**: Add, edit, and delete backups.
- **Manage Accounts**: Add, edit, and delete user accounts.
- **Configure Email Server**: Update email server settings and port numbers.
- **Install Updates**: Access and manage software updates and licenses.

### Moderator
Moderators have slightly restricted permissions:
- **Manage Backups**: Similar to Admins, but without user account management.
- **Move Backup Status Squares**: Adjust the position of backup status indicators.
- **View Account Configuration**: Can update their own account details.

### Guest
Guests have the most limited access:
- **View Backup Status**: Only view current backup statuses.
- **Account Configuration**: Update their own account details but no access to manage backups.


## Getting Started

To start using BackupWatch:
1. **Log In**: Use your credentials.
2. **Admin Access**: Admins can manage user accounts, mail configuration, and version updates.
3. **Add Backups**: Go to "Add New" to create a new backup entry.


## Understanding Status Indicators

BackupWatch uses color-coded squares to indicate the status of each backup:

- 🟢 **Green**: Backup completed successfully.
- 🟡 **Yellow**: Backup is delayed by one interval.
- 🟣 **Purple**: Backup is delayed by two intervals.
- 🔴 **Red**: Backup failed or encountered an error.


## Additional Features

Admins can:
- **Configure Email Server Settings**
- **Change Port Number**
- **Manage User Accounts**
- **Check for Updates**: Ensure the application is up-to-date with the latest features and security patches.

---

# 🔷 Installation on Ubuntu 22.04

To install BackupWatch on Ubuntu 22.04, follow these steps:

```
sudo apt-get update
```
```
sudo apt-get upgrade -y
```
```
curl -s https://raw.githubusercontent.com/stefanzeljkic/BackupWatch/main/install_backupwatch.sh | bash
```

After the installation, the application will be available at `http://<your-ip-address>:8000`.

### Default Admin Credentials

- **Username**: `admin`
- **Password**: `admin`

Make sure to change these credentials after the first login to ensure the security of your BackupWatch instance.


### Additional Commands (for Troubleshooting):

If needed, you can restart the BackupWatch service and check its status with the following commands:

```
sudo systemctl restart backupwatch.service
```
```
sudo systemctl status backupwatch.service
```
If you need to run application manualy:

```
python3 /opt/BackupWatch/app.py
```
### Time zones

Application time is tied to the server's time zone
To check time zone:
```
timedatectl
```
Setup time zone 'Example for Belgrade':
```
sudo timedatectl set-timezone Europe/Belgrade
```
List of all time zones:
```
timedatectl list-timezones
```
Find your time zone and apply to sudo timedatectl set-timezone "time zone" and restart service:
```
sudo systemctl restart backupwatch.service
```


---

