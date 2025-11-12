# ================== Inputs (Skillable tokens) ==================
$clientId             = "@lab.CloudSubscription.AppId"
$clientSecret         = "@lab.CloudSubscription.AppSecret"
$tenantId             = "@lab.CloudSubscription.TenantId"
$subscriptionId       = "@lab.CloudSubscription.Id"
$resourceGroupName    = "@lab.CloudResourceGroup(ResourceGroup1).Name"
$aadUserPrincipalName = "@lab.CloudPortalCredential(User1).Username"
$aadUserPassword      = "@lab.CloudPortalCredential(User1).Password"

Write-Host "Getting access token for Azure Management..."

# Get OAuth2 token for Azure Resource Manager
$tokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    resource      = "https://management.azure.com/"
}

$tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/token" `
    -Method POST `
    -Body $tokenBody `
    -ContentType "application/x-www-form-urlencoded"

$token = $tokenResponse.access_token
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

Write-Host "Discovering PostgreSQL Flexible Server..."

# List PostgreSQL Flexible Servers in the resource group
$serversUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DBforPostgreSQL/flexibleServers?api-version=2023-03-01-preview"

$serversResponse = Invoke-RestMethod -Uri $serversUri -Method GET -Headers $headers
$postgresServerName = $serversResponse.value[0].name

Write-Host "PostgreSQL Server: $postgresServerName"
Write-Host ""

# Set azure.extensions parameter
Write-Host "Setting azure.extensions parameter..."
$extensionsUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DBforPostgreSQL/flexibleServers/$postgresServerName/configurations/azure.extensions?api-version=2023-03-01-preview"

$extensionsBody = @{
    properties = @{
        value  = "azure_ai,pg_diskann,vector,age,azure_storage"
        source = "user-override"
    }
} | ConvertTo-Json

$extensionsResult = Invoke-RestMethod -Uri $extensionsUri -Method PUT -Headers $headers -Body $extensionsBody
Write-Host "azure.extensions parameter updated"
Write-Host ""

# Set shared_preload_libraries parameter
Write-Host "Setting shared_preload_libraries parameter..."
$preloadUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DBforPostgreSQL/flexibleServers/$postgresServerName/configurations/shared_preload_libraries?api-version=2023-03-01-preview"

$preloadBody = @{
    properties = @{
        value  = "age,azure_storage,pg_cron,pg_stat_statements"
        source = "user-override"
    }
} | ConvertTo-Json

$preloadResult = Invoke-RestMethod -Uri $preloadUri -Method PUT -Headers $headers -Body $preloadBody
Write-Host "shared_preload_libraries parameter updated"
Write-Host ""

# Restart the PostgreSQL server
Write-Host "Restarting PostgreSQL server (this will take 60-120 seconds)..."
$restartUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DBforPostgreSQL/flexibleServers/$postgresServerName/restart?api-version=2023-03-01-preview"

$restartResult = Invoke-RestMethod -Uri $restartUri -Method POST -Headers $headers
Write-Host "Server restart initiated"

# Wait for the restart operation to complete
Write-Host "Waiting for server to restart..."
Start-Sleep -Seconds 90

Write-Host ""
Write-Host "PostgreSQL server configuration complete!"
Write-Host "The AGE extension and required libraries are now enabled."