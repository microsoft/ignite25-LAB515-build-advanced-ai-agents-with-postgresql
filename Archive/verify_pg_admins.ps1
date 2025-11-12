# Verify PostgreSQL Administrators Configuration

# ================== Inputs (Skillable tokens) ==================
$clientId             = "@lab.CloudSubscription.AppId"
$clientSecret         = "@lab.CloudSubscription.AppSecret"
$tenantId             = "@lab.CloudSubscription.TenantId"
$subscriptionId       = "@lab.CloudSubscription.Id"
$resourceGroupName    = "@lab.CloudResourceGroup(ResourceGroup1).Name"

# Get ARM token
$tokMgmt = Invoke-RestMethod -Method POST `
  -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
  -ContentType 'application/x-www-form-urlencoded' -Body @{
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = 'https://management.azure.com/.default'
    grant_type    = 'client_credentials'
  }

$armHeaders = @{
  Authorization = "Bearer $($tokMgmt.access_token)"
  "Content-Type" = "application/json"
}

# Get PostgreSQL Server
$postgresUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DBforPostgreSQL/flexibleServers?api-version=2023-03-01-preview"
$postgresResponse = Invoke-RestMethod -Uri $postgresUrl -Headers $armHeaders -Method Get
$serverName = $postgresResponse.value[0].name

Write-Output "PostgreSQL Server: $serverName"
Write-Output ""

# List all administrators
$adminsUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DBforPostgreSQL/flexibleServers/$serverName/administrators?api-version=2023-03-01-preview"

try {
    $adminsResponse = Invoke-RestMethod -Uri $adminsUrl -Headers $armHeaders -Method Get
    
    Write-Output "Configured Administrators:"
    Write-Output "=========================="
    foreach ($admin in $adminsResponse.value) {
        Write-Output "Name: $($admin.name)"
        Write-Output "  Principal Type: $($admin.properties.principalType)"
        Write-Output "  Principal Name: $($admin.properties.principalName)"
        Write-Output "  Tenant ID: $($admin.properties.tenantId)"
        Write-Output ""
    }
} catch {
    Write-Output "Error listing administrators: $($_.Exception.Message)"
}
