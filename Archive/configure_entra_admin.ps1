# Define log file path
$logDir = 'C:\Lab\Logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir ("entra-admin-log_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

# Simple helper function for logging
function Write-Log {
  param([string]$Message)
  $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  "$timestamp $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}

Write-Log "==== Entra Admin Configuration Start ===="

# ================== Inputs (Skillable tokens) ==================
$clientId             = "@lab.CloudSubscription.AppId"
$clientSecret         = "@lab.CloudSubscription.AppSecret"
$tenantId             = "@lab.CloudSubscription.TenantId"
$subscriptionId       = "@lab.CloudSubscription.Id"
$rgName               = "@lab.CloudResourceGroup(ResourceGroup1).Name"
$aadUserPrincipalName = "@lab.CloudPortalCredential(User1).Username"

Write-Log "ClientId: $clientId"
Write-Log "TenantId: $tenantId"
Write-Log "SubscriptionId: $subscriptionId"
Write-Log "ResourceGroup: $rgName"
Write-Log "AAD User Principal Name: $aadUserPrincipalName"

# ================== Fast, deterministic environment ==================
$ErrorActionPreference = 'Stop'
$env:AZURE_CONFIG_DIR = "C:\Temp\.azure"
New-Item -ItemType Directory -Force $env:AZURE_CONFIG_DIR | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ================== Get ARM token via OAuth2 client credentials ==================
Write-Log "Obtaining ARM management token..."

$ct = 'application/x-www-form-urlencoded'
$tokMgmt = Invoke-RestMethod -Method POST `
  -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
  -ContentType $ct -Body @{
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = 'https://management.azure.com/.default'
    grant_type    = 'client_credentials'
  }

$armHeaders = @{
  Authorization = "Bearer $($tokMgmt.access_token)"
  "Content-Type" = "application/json"
}

Write-Log "ARM token obtained successfully"

# ================== Get PostgreSQL Server Name ==================
Write-Log "Retrieving PostgreSQL server name from resource group..."

try {
  # List PostgreSQL flexible servers in the resource group
  $listServersUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$rgName/providers/Microsoft.DBforPostgreSQL/flexibleServers`?api-version=2023-03-01-preview"
  
  $serversResponse = Invoke-RestMethod -Method GET -Uri $listServersUri -Headers $armHeaders
  
  if ($serversResponse.value -and $serversResponse.value.Count -gt 0) {
    $serverName = $serversResponse.value[0].name
    Write-Log "Found PostgreSQL server: $serverName"
  } else {
    throw "No PostgreSQL flexible servers found in resource group: $rgName"
  }
} catch {
  Write-Log "Error retrieving PostgreSQL server: $_"
  throw
}

# ================== Configure Microsoft Entra Admin for PostgreSQL ==================
Write-Log "Configuring Microsoft Entra admin for PostgreSQL server"

try {
  # Get Microsoft Graph API token
  Write-Log "Obtaining Microsoft Graph token..."
  
  $graphToken = Invoke-RestMethod -Method POST `
    -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
    -ContentType 'application/x-www-form-urlencoded' -Body @{
      client_id     = $clientId
      client_secret = $clientSecret
      scope         = 'https://graph.microsoft.com/.default'
      grant_type    = 'client_credentials'
    }
  
  $graphHeaders = @{
    Authorization = "Bearer $($graphToken.access_token)"
    "Content-Type" = "application/json"
  }
  
  Write-Log "Graph token obtained successfully"
  
  # Get user object ID from Microsoft Graph
  $userUri = "https://graph.microsoft.com/v1.0/users/$aadUserPrincipalName"
  Write-Log "Querying user: $userUri"
  
  $user = Invoke-RestMethod -Method GET -Uri $userUri -Headers $graphHeaders
  $objectId = $user.id
  
  Write-Log "User Object ID: $objectId"
  
  # Configure Entra admin on PostgreSQL server
  $adminUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$rgName/providers/Microsoft.DBforPostgreSQL/flexibleServers/$serverName/administrators/$objectId`?api-version=2023-03-01-preview"
  
  Write-Log "Configuring Entra admin URI: $adminUri"
  
  $adminBody = @{
    properties = @{
      principalType = "User"
      principalName = $aadUserPrincipalName
      tenantId      = $tenantId
    }
  } | ConvertTo-Json -Depth 10
  
  Write-Log "Admin request body: $adminBody"
  
  $adminResult = Invoke-RestMethod -Method PUT -Uri $adminUri -Headers $armHeaders -Body $adminBody
  
  Write-Log "==== Microsoft Entra admin configured successfully ===="
  Write-Log "Admin details: $($adminResult | ConvertTo-Json -Depth 5)"
  
  Write-Host "Microsoft Entra admin configured successfully for server: $serverName" -ForegroundColor Green
  Write-Host "User: $aadUserPrincipalName" -ForegroundColor Green
  
} catch {
  Write-Log "Error configuring Microsoft Entra admin: $_"
  Write-Log "Error details: $($_.Exception.Message)"
  
  if ($_.Exception.Response) {
    try {
      $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $responseBody = $reader.ReadToEnd()
      Write-Log "Error response: $responseBody"
      Write-Host "Error response: $responseBody" -ForegroundColor Red
    } catch {
      Write-Log "Could not read error response"
    }
  }
  
  throw
}

Write-Log "==== Entra Admin Configuration Complete ===="
