<#
.SYNOPSIS
  Generate a .env file at the project root with values from the Azure Developer CLI and Azure CLI.

.DESCRIPTION
  PowerShell version of the original Bash script:
    - Clears or creates ./.env
    - Appends Azure OpenAI and Database config values from `azd`
    - Enriches the file with live Azure resource details retrieved via `az`
#>

# Fail fast on errors
$ErrorActionPreference = 'Stop'

# Ensure required CLIs are available
if (-not (Get-Command azd -ErrorAction SilentlyContinue)) {
    throw "The 'azd' CLI was not found in PATH. Please install Azure Developer CLI and try again."
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "The 'az' CLI was not found in PATH. Please install Azure CLI and try again."
}

# Define the .env file path - project root
$EnvFilePath = Join-Path -Path (Resolve-Path "$PSScriptRoot\..") -ChildPath ".env"

# Clear the contents of the .env file or create it if it doesn't exist
# Using UTF8 (no BOM) for compatibility
"" | Set-Content -Path $EnvFilePath -Encoding utf8

function Get-AzdValue {
    param(
        [Parameter(Mandatory=$true)]
        [string] $Name
    )
    # Capture output; trim to avoid trailing newlines/spaces
    $val = azd env get-value $Name 2>$null
    if ($LASTEXITCODE -ne 0) {
        # If the value doesn't exist, keep it empty but don't fail the whole script
        return ""
    }
    return ($val | Out-String).Trim()
}

# Resolve Azure resource identifiers needed for direct queries
$azureEnvName = Get-AzdValue -Name "AZURE_ENV_NAME"
if (-not $azureEnvName) {
    throw "AZURE_ENV_NAME was not found in the azd environment. Ensure 'azd env get-value AZURE_ENV_NAME' succeeds."
}

$subscriptionId = Get-AzdValue -Name "AZURE_SUBSCRIPTION_ID"
if (-not $subscriptionId) {
    throw "AZURE_SUBSCRIPTION_ID was not found in the azd environment. Ensure 'azd env get-value AZURE_SUBSCRIPTION_ID' succeeds."
}

$resourceGroupName = "rg-$azureEnvName"

$openaiResourceName = (az cognitiveservices account list --resource-group $resourceGroupName --subscription $subscriptionId --query "[?kind=='OpenAI'].name | [0]" --output tsv).Trim()
if (-not $openaiResourceName) {
    throw "No Azure OpenAI resource found in resource group '$resourceGroupName'."
}

$openaiEndpoint = (az cognitiveservices account show --name $openaiResourceName --resource-group $resourceGroupName --subscription $subscriptionId --query "properties.endpoint" --output tsv).Trim()
if (-not $openaiEndpoint) {
    throw "Failed to resolve the Azure OpenAI endpoint for '$openaiResourceName'."
}

$openaiKey = (az cognitiveservices account keys list --name $openaiResourceName --resource-group $resourceGroupName --subscription $subscriptionId --query "key1" --output tsv).Trim()
if (-not $openaiKey) {
    throw "Failed to fetch an Azure OpenAI key for '$openaiResourceName'."
}

$postgresServerName = (az postgres flexible-server list --resource-group $resourceGroupName --subscription $subscriptionId --query "[0].name" --output tsv).Trim()
if (-not $postgresServerName) {
    throw "No Azure PostgreSQL Flexible Server found in resource group '$resourceGroupName'."
}

$postgresHost = (az postgres flexible-server show --name $postgresServerName --resource-group $resourceGroupName --subscription $subscriptionId --query "fullyQualifiedDomainName" --output tsv).Trim()
if (-not $postgresHost) {
    throw "Failed to resolve the PostgreSQL server FQDN for '$postgresServerName'."
}

# Use Entra ID token as the password when connecting with AAD auth
$token = az account get-access-token --resource-type oss-rdbms --subscription $subscriptionId --output json | ConvertFrom-Json
$accessToken = ($token.accessToken | Out-String).Trim()
if (-not $accessToken) {
    throw "Failed to obtain an Entra ID access token for the PostgreSQL server."
}

# --- Azure OpenAI Configuration ---
Add-Content -Path $EnvFilePath -Encoding utf8 "# Azure OpenAI Configuration"
Add-Content -Path $EnvFilePath -Encoding utf8 ("AZURE_OPENAI_ENDPOINT={0}"     -f $openaiEndpoint)
Add-Content -Path $EnvFilePath -Encoding utf8 ("AZURE_OPENAI_DEPLOYMENT={0}"   -f (Get-AzdValue -Name "AZURE_OPENAI_CHAT_DEPLOYMENT"))
Add-Content -Path $EnvFilePath -Encoding utf8 ("AZURE_EMBED_DEPLOYMENT={0}"    -f (Get-AzdValue -Name "AZURE_OPENAI_EMB_DEPLOYMENT"))
Add-Content -Path $EnvFilePath -Encoding utf8 ("AZURE_OPENAI_KEY={0}"          -f $openaiKey)
Add-Content -Path $EnvFilePath -Encoding utf8 ("AZURE_API_VERSION={0}"         -f "2024-11-20")
Add-Content -Path $EnvFilePath -Encoding utf8 ""

# --- Database Configuration ---
Add-Content -Path $EnvFilePath -Encoding utf8 "# Database Configuration"
Add-Content -Path $EnvFilePath -Encoding utf8 ("AZURE_PG_HOST={0}"             -f $postgresHost)
Add-Content -Path $EnvFilePath -Encoding utf8 ("AZURE_PG_NAME={0}"             -f (Get-AzdValue -Name "AZURE_POSTGRES_DBNAME"))
Add-Content -Path $EnvFilePath -Encoding utf8 ("AZURE_PG_USER={0}"             -f (Get-AzdValue -Name "AZURE_POSTGRES_USER"))
Add-Content -Path $EnvFilePath -Encoding utf8 ("AZURE_PG_PASSWORD={0}"         -f $accessToken)
Add-Content -Path $EnvFilePath -Encoding utf8 ("AZURE_PG_PORT={0}"             -f "5432")
Add-Content -Path $EnvFilePath -Encoding utf8 ("AZURE_PG_SSLMODE={0}"          -f "require")

Write-Host "Environment file created at $EnvFilePath"