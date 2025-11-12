# Configure Service Principal as PostgreSQL Administrator
# This script adds the service principal as an administrator to the PostgreSQL server
# so that it can authenticate using its app token

# ================== Inputs (Skillable tokens) ==================
$clientId             = "@lab.CloudSubscription.AppId"
$clientSecret         = "@lab.CloudSubscription.AppSecret"
$tenantId             = "@lab.CloudSubscription.TenantId"
$subscriptionId       = "@lab.CloudSubscription.Id"
$resourceGroupName    = "@lab.CloudResourceGroup(ResourceGroup1).Name"

# ================== Get ARM token via OAuth2 client credentials ==================
Write-Output "Getting ARM access token..."
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

# ================== Get PostgreSQL Server Name ==================
Write-Output "Finding PostgreSQL server..."
$postgresUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DBforPostgreSQL/flexibleServers?api-version=2023-03-01-preview"
$postgresResponse = Invoke-RestMethod -Uri $postgresUrl -Headers $armHeaders -Method Get

$postgresServer = $postgresResponse.value | Select-Object -First 1
$serverName = $postgresServer.name

if (-not $serverName) {
    Write-Output "Error: No PostgreSQL server found in resource group $resourceGroupName"
    exit 1
}

Write-Output "Found PostgreSQL server: $serverName"

# ================== Get Microsoft Graph API token ==================
Write-Output "Getting Microsoft Graph token..."
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

# ================== Get Service Principal Object ID ==================
Write-Output "Looking up service principal object ID..."
$spUri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$clientId'"
$spResponse = Invoke-RestMethod -Method GET -Uri $spUri -Headers $graphHeaders

if ($spResponse.value.Count -eq 0) {
    Write-Output "Error: Service principal not found for app ID $clientId"
    exit 1
}

$spObjectId = $spResponse.value[0].id
$spDisplayName = $spResponse.value[0].displayName

Write-Output "Service Principal: $spDisplayName"
Write-Output "Object ID: $spObjectId"

# ================== Configure Service Principal as PostgreSQL Administrator ==================
Write-Output "Configuring service principal as PostgreSQL administrator..."
$adminUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DBforPostgreSQL/flexibleServers/$serverName/administrators/$spObjectId`?api-version=2023-03-01-preview"

$adminBody = @{
  properties = @{
    principalType = "ServicePrincipal"
    principalName = $spDisplayName
    tenantId      = $tenantId
  }
} | ConvertTo-Json -Depth 10

Write-Output "Admin URI: $adminUri"

try {
    $adminResult = Invoke-RestMethod -Method PUT -Uri $adminUri -Headers $armHeaders -Body $adminBody
    Write-Output ""
    Write-Output "Service principal configured successfully as PostgreSQL administrator"
    Write-Output ""
    Write-Output "You can now use the service principal to connect to PostgreSQL with:"
    Write-Output "  Username: $clientId@$tenantId"
    Write-Output "  Password: [service principal token for ossrdbms-aad.database.windows.net]"
    Write-Output ""
} catch {
    Write-Output "Error configuring administrator: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Output "Response: $responseBody"
        } catch {
            Write-Output "Could not read error response"
        }
    }
    exit 1
}
