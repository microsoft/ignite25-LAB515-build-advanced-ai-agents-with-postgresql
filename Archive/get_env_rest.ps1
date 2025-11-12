# PowerShell script to retrieve Azure resources using REST API and generate .env file

# ================== Inputs (Skillable tokens) ==================
$clientId             = "@lab.CloudSubscription.AppId"
$clientSecret         = "@lab.CloudSubscription.AppSecret"
$tenantId             = "@lab.CloudSubscription.TenantId"
$subscriptionId       = "@lab.CloudSubscription.Id"
$resourceGroupName    = "@lab.CloudResourceGroup(ResourceGroup1).Name"
$aadUserPrincipalName = "@lab.CloudPortalCredential(User1).Username"
$aadUserPassword      = "@lab.CloudPortalCredential(User1).Password"

# ================== Get ARM token via OAuth2 client credentials ==================
$ct = 'application/x-www-form-urlencoded'
$tokMgmt = Invoke-RestMethod -Method POST `
  -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
  -ContentType $ct -Body @{
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = 'https://management.azure.com/.default'
    grant_type    = 'client_credentials'
  }

$armToken = $tokMgmt.access_token

# Construct the REST API URL to list Cognitive Services accounts
$cognitiveServicesUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.CognitiveServices/accounts?api-version=2023-05-01"

# Make REST API call to get Cognitive Services accounts
$headers = @{
    "Authorization" = "Bearer $armToken"
    "Content-Type" = "application/json"
}

$cognitiveAccounts = Invoke-RestMethod -Uri $cognitiveServicesUrl -Headers $headers -Method Get

# Find the first OpenAI account
$openaiAccount = $cognitiveAccounts.value | Where-Object { $_.kind -eq "OpenAI" } | Select-Object -First 1
$openaiResourceName = $openaiAccount.name

# Get OpenAI endpoint
$openaiEndpoint = $openaiAccount.properties.endpoint

# Get OpenAI keys
$keysUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.CognitiveServices/accounts/$openaiResourceName/listKeys?api-version=2023-05-01"
$keysResponse = Invoke-RestMethod -Uri $keysUrl -Headers $headers -Method Post
$openaiKey = $keysResponse.key1

# Get OpenAI deployments
$deploymentsUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.CognitiveServices/accounts/$openaiResourceName/deployments?api-version=2023-05-01"
$deploymentsResponse = Invoke-RestMethod -Uri $deploymentsUrl -Headers $headers -Method Get

# Find gpt-4o and text-embedding-3-small deployments
$gptDeployment = $deploymentsResponse.value | Where-Object { $_.properties.model.name -like "*gpt-4o*" } | Select-Object -First 1
$embedDeployment = $deploymentsResponse.value | Where-Object { $_.properties.model.name -like "*text-embedding-3-small*" } | Select-Object -First 1

$gptDeploymentName = if ($gptDeployment) { $gptDeployment.name } else { "gpt-4o" }
$embedDeploymentName = if ($embedDeployment) { $embedDeployment.name } else { "text-embedding-3-small" }

# Get PostgreSQL Flexible Server
$postgresUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DBforPostgreSQL/flexibleServers?api-version=2023-03-01-preview"
$postgresResponse = Invoke-RestMethod -Uri $postgresUrl -Headers $headers -Method Get

$postgresServer = $postgresResponse.value | Select-Object -First 1
$postgresServerName = $postgresServer.name
$postgresHost = $postgresServer.properties.fullyQualifiedDomainName

# Get the current user UPN for PostgreSQL authentication
$currentUser = $aadUserPrincipalName

# Try to get USER access token for PostgreSQL (ossrdbms) via Resource Owner Password Credentials (ROPC) flow
Write-Output "Getting PostgreSQL access token for user: $aadUserPrincipalName"
try {
    $tokOssRdbms = Invoke-RestMethod -Method POST `
      -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
      -ContentType 'application/x-www-form-urlencoded' -Body @{
        client_id     = $clientId
        scope         = 'https://ossrdbms-aad.database.windows.net/.default'
        username      = $aadUserPrincipalName
        password      = $aadUserPassword
        grant_type    = 'password'
      }
    
    $dbToken = $tokOssRdbms.access_token
    Write-Output "PostgreSQL USER token acquired successfully"
    Write-Output "Using user as PostgreSQL user: $currentUser"
} catch {
    Write-Output "ROPC flow failed, trying service principal token as fallback..."
    
    # Fallback to service principal token
    try {
        $tokOssRdbms = Invoke-RestMethod -Method POST `
          -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
          -ContentType 'application/x-www-form-urlencoded' -Body @{
            client_id     = $clientId
            client_secret = $clientSecret
            scope         = 'https://ossrdbms-aad.database.windows.net/.default'
            grant_type    = 'client_credentials'
          }
        
        $dbToken = $tokOssRdbms.access_token
        $currentUser = $clientId
        Write-Output "PostgreSQL SERVICE PRINCIPAL token acquired successfully"
        Write-Output "Using service principal as PostgreSQL user: $currentUser"
    } catch {
        Write-Output "Error: Failed to get PostgreSQL token. Error: $($_.Exception.Message)"
        $dbToken = ""
    }
}

# Create .env file content
$envContent = @"
# Azure OpenAI Configuration
AZURE_OPENAI_ENDPOINT=$($openaiEndpoint)
AZURE_OPENAI_KEY=$($openaiKey)
AZURE_OPENAI_DEPLOYMENT=$($gptDeploymentName)
AZURE_EMBED_DEPLOYMENT=$($embedDeploymentName)
AZURE_API_VERSION=2024-12-01-preview

# Database Configuration
AZURE_PG_HOST=$($postgresHost)
AZURE_PG_NAME=cases
AZURE_PG_USER=$($currentUser)
AZURE_PG_PASSWORD=$($dbToken)
AZURE_PG_PORT=5432
AZURE_PG_SSLMODE=require
"@

# Determine the path for .env file (one level up from Scripts folder)
$scriptDir = Split-Path -Parent $PSCommandPath
$envFilePath = Join-Path (Split-Path -Parent $scriptDir) ".env"

# Write the .env file
$envContent | Out-File -FilePath $envFilePath -Encoding utf8 -NoNewline

Write-Output ""
Write-Output ".env file created successfully at: $envFilePath"
Write-Output ""
Write-Output "Configuration retrieved:"
Write-Output "  Azure OpenAI Endpoint: $openaiEndpoint"
Write-Output "  Azure OpenAI Deployment: $gptDeploymentName"
Write-Output "  Embedding Deployment: $embedDeploymentName"
Write-Output "  PostgreSQL Host: $postgresHost"
Write-Output "  PostgreSQL Database: cases"
Write-Output "  PostgreSQL User: $currentUser"
Write-Output ""
