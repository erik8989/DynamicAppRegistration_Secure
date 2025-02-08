# DynamicAppRegistration_Secure
Secure Mailbox Access with Microsoft Graph & Entra ID

For detailed Info, visit my Blog!
https://m365blog.com/secure-mailbox-access-with-microsoft-graph-entra-id/

Overview

This repository contains a PowerShell script that automates the creation of an Entra ID application with restricted access to a specific Microsoft 365 mailbox. The script dynamically assigns Microsoft Graph API permissions, enforces Application Access Policies, and streamlines the process of securing mailbox access.

    Important: Before running the script, ensure you update the necessary values such as permissions, mailbox, and tenant-specific details. These placeholders must be customized for your environment to work correctly.
    Key Features

✅ Automated Entra ID App Creation – No manual configuration needed
✅ Granular Mailbox Access Control – Uses Application Access Policies to limit API access to a specific mailbox
✅ Dynamic Permission Assignment – Fetches the required Microsoft Graph API permissions automatically
✅ Secure Client Secret Storage & Retrieval – Encrypts and allows decryption for third-party use
✅ Admin Consent Automation – Eliminates manual approval steps
✅ Scalable & Maintainable – Works for any mailbox with minimal modifications

Getting Started
1️⃣ Prerequisites

Ensure you have the following PowerShell modules installed:

Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser

Contributing

If you’d like to contribute, feel free to fork the repository, submit issues, or create pull requests.
Resources

📌 Microsoft Graph Permissions – Learn More
📌 Application Access Policies in Exchange Online – Learn More
License

This project is licensed under the MIT License.
