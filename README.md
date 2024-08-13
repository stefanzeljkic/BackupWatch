
BackupWatch Documentation
Introduction

BackupWatch is a web-based application designed to monitor the status of backups through emails. The application checks incoming emails for specific keywords that indicate the success or failure of a backup operation. Based on the keywords found, BackupWatch updates the status of each backup, helping administrators easily identify which backups have succeeded or failed.
License and Open-Source Nature

BackupWatch is an open-source project licensed under the Apache-2.0 license. This means that you are free to use, modify, and distribute the software under the terms of the license. As an open-source project, BackupWatch encourages community contributions and collaboration. You can review the source code, suggest improvements, and contribute to the project on its public repository.

The open-source nature of BackupWatch ensures that it remains transparent, secure, and customizable according to your needs. By using an open-source license, the application promotes innovation and trust among its users, who can inspect and improve the codebase as necessary.
Features

BackupWatch offers a range of features to help you monitor and manage your backups effectively:

    Backup Monitoring: Automatically checks emails for backup success or failure based on user-defined keywords.
    Real-time Status Updates: Displays the current status of backups with color-coded indicators.
    Automatic Refresh: Periodically refreshes the status of backups based on a configurable interval.
    Account Management: Allows administrators to manage user accounts, including adding, updating, and deleting users.
    Customizable Configuration: Adjust settings such as email server details, port number, and refresh intervals through a user-friendly interface.
    Version Updates: Check for and install new versions of the application with ease.
    License Information: Access detailed license information for BackupWatch.
    Dark and Light Mode: Toggle between dark and light themes based on user preference.

User Roles and Permissions

BackupWatch supports multiple user roles, each with different levels of access and capabilities. Understanding these roles is essential for managing the application effectively:
Admin

The Admin role has the highest level of access within BackupWatch. Admins can perform the following tasks:

    Manage Users: Create, update, and delete user accounts.
    Configure Email Settings: Modify email server settings, including IMAP and SMTP configurations.
    Manage Backups: Add, edit, and delete backups. Admins can also move backup status squares on the dashboard.
    Access Administration Panel: Access features such as version updates, changing the port, and configuring automatic refresh intervals.
    View and Update License Information: Access and manage the software license.

Moderator

Moderators have a slightly restricted set of permissions compared to Admins. They can perform the following tasks:

    Manage Backups: Add, edit, and delete backups, similar to Admins.
    Move Backup Status Squares: Adjust the position of backup status squares on the dashboard.
    View Account Configuration: Moderators can view and update their account details but cannot manage other user accounts.

Guest

The Guest role has the most limited access within BackupWatch. Guests can only view the status of backups without the ability to make changes. Specifically, Guests can:

    View Backup Status: See the current status of all backups on the dashboard.
    Account Configuration: Guests can view and update their account details but have no access to manage backups or other settings.

Getting Started

To start using BackupWatch, log in with your credentials. If you are an administrator, you will have access to additional features such as user management, mail configuration, and version updates.
Managing Backups

To add a new backup, navigate to the "Add New" section and fill out the required details, including the backup name, email address, email subject, and the keywords to identify success and failure. Once added, BackupWatch will begin monitoring emails and updating the status accordingly.
Understanding Status Indicators

BackupWatch uses color-coded squares to indicate the status of each backup:

    Green: Backup completed successfully.
    Yellow: Backup is delayed by one interval.
    Purple: Backup is delayed by two intervals.
    Red: Backup failed or encountered an error.

Additional Features

As an administrator, you can configure the email server settings, change the port number, and manage user accounts through the "Administration" section. Additionally, you can check for new versions of BackupWatch and install updates to keep the application up-to-date with the latest features and security patches.
