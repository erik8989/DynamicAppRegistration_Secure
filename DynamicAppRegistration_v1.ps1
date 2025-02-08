<#
.SYNOPSIS
This script creates an Azure AD application with restricted access to a specific mailbox.
It dynamically assigns Microsoft Graph API permissions and enforces access policies.

.DESCRIPTION
- Registers a new Azure AD application and service principal.
- Dynamically assigns Microsoft Graph API permissions (e.g., Mail.Read, Mail.Send).
- Enforces admin consent automatically.
- Creates a security group to restrict API access to a specific mailbox.
- Configures an Application Access Policy in Exchange Online.

.AUTHOR
Erik Hüttmeyer - m365blog.com

.VERSION
1.0

.NOTES
Ensure you have the necessary permissions before running this script:
- Global Admin or Privileged Role Admin in Entra ID
- Exchange Online Administrator
#>

# Define variables
$AppName = "AppNAme"
$Mailbox = "YourMailbox"
$API_Permissions = @("Mail.Read", "Mail.Send") # Define required permissions
$ClientSecretPath = "C:\Temp\ClientSecret.txt" # Path to store the Client Secret
$GraphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'" -Property "Id"
$GraphResourceId = $GraphServicePrincipal.Id

# Connect to Microsoft Graph
#Connect-MgGraph -Scopes AppRoleAssignment.ReadWrite.All,Application.ReadWrite.All -NoWelcome

# Function to dynamically generate requiredResourceAccess object
function New-GraphPermissionObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Permissions
    )
    
    try {
        Write-Host "Fetching Microsoft Graph Service Principal..."
        $msGraphSP = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'" -Property "appRoles,oauth2PermissionScopes"
    }
    catch {
        Write-Error "Error retrieving Microsoft Graph Service Principal. Ensure you're connected via Connect-MgGraph with the required permissions."
        return
    }
    
    if (-not $msGraphSP) {
        Write-Error "Microsoft Graph Service Principal could not be found!"
        return
    }
    
    $resourceAccess = @()

    foreach ($perm in $Permissions) {
        $found = $null
        $appRole = $msGraphSP.AppRoles | Where-Object { $_.Value -eq $perm -and $_.AllowedMemberTypes -contains "Application" }
        
        if ($appRole) {
            $found = @{ id = $appRole.Id; type = "Role" }
        }
        else {
            $scope = $msGraphSP.Oauth2PermissionScopes | Where-Object { $_.Value -eq $perm }
            if ($scope) {
                $found = @{ id = $scope.Id; type = "Scope" }
            }
        }

        if ($found) {
            $resourceAccess += $found
            Write-Host "Added permission: $perm (Type: $($found.type), ID: $($found.id))"
        }
        else {
            Write-Warning "Permission '$perm' not found in Microsoft Graph!"
        }
    }

    return @{ resourceAccess = $resourceAccess; resourceAppId = "00000003-0000-0000-c000-000000000000" }
}

# Step 1: Generate permissions object
$requiredResourceAccess = @(New-GraphPermissionObject -Permissions $API_Permissions)
Write-Host "Final Resource Access Configuration:" 
$requiredResourceAccess | ConvertTo-Json -Depth 4 | Write-Output

# Step 2: Create the Azure AD Application
$app = New-MgApplication -DisplayName $AppName -RequiredResourceAccess $requiredResourceAccess
$AppId = $app.AppId
Write-Host "Created Azure AD Application: $AppName (ID: $AppId)"

# Step 3: Create a Service Principal
$sp = New-MgServicePrincipal -AppId $AppId
$ServicePrincipalObjectId = $sp.Id
Write-Host "Created Service Principal (ID: $ServicePrincipalObjectId)"

# Step 4: Create and store Client Secret
$Secret = Add-MgApplicationPassword -ApplicationId $App.Id
$EncryptedSecret = ConvertTo-SecureString -String $Secret.SecretText -AsPlainText -Force
$EncryptedSecret | ConvertFrom-SecureString | Out-File $ClientSecretPath
Write-Host "Client Secret securely stored at: $ClientSecretPath"

# Step 5: Grant Admin Consent
foreach ($access in $requiredResourceAccess.resourceAccess) {
    $Body = @{ principalId = $ServicePrincipalObjectId; resourceId = $GraphResourceId; appRoleId = $access.id } | ConvertTo-Json -Depth 3
    Write-Host "Granting Admin Consent for AppRole ID: $($access.id)..."
    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$ServicePrincipalObjectId/appRoleAssignments" -Body $Body -ContentType "application/json"
    Write-Host "Admin Consent granted for AppRole ID: $($access.id)"
}

# Step 6: Connect to Exchange Online
#Connect-ExchangeOnline -Organization $TenantId

# Step 7: Create or update Security Group
$AccessGroupName = "MailDaemonAccessGroup"
$GroupExists = Get-Recipient -RecipientTypeDetails MailUniversalSecurityGroup | Where-Object { $_.DisplayName -eq $AccessGroupName }
if (-not $GroupExists) {
    New-DistributionGroup -Name $AccessGroupName -Type Security
    Start-Sleep -Seconds 15
}

# Add Mailbox to Security Group if not already a member
$GroupMembers = Get-DistributionGroupMember -Identity $AccessGroupName
if ($GroupMembers -and ($GroupMembers.PrimarySmtpAddress -notcontains $Mailbox)) {
    Add-DistributionGroupMember -Identity $AccessGroupName -Member $Mailbox
} else {
    Write-Host "Mailbox is already a member of the security group. Skipping addition."
}

# Step 8: Create Application Access Policy
New-ApplicationAccessPolicy -AppId $AppId -PolicyScopeGroupId $AccessGroupName -AccessRight RestrictAccess -Description "Restricts API access to $Mailbox"

# Step 9: Output results
Write-Host "Azure AD App successfully created!"
Write-Host "Client ID: $AppId"
Write-Host "Tenant ID: $(Get-MgContext).TenantId"
Write-Host "Client Secret is stored securely at: '$ClientSecretPath'"
