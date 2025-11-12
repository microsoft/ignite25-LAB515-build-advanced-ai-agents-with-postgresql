# Set the resource group name
$resourceGroupName = "ResourceGroup1"

# Get the first Azure OpenAI service in the resource group
$openaiResourceName = az cognitiveservices account list --resource-group $resourceGroupName --query "[?kind=='OpenAI'].name | [0]" --output tsv

# Fetch Azure OpenAI Endpoint
$openaiEndpoint = az cognitiveservices account show --name $openaiResourceName --resource-group $resourceGroupName --query "properties.endpoint" --output tsv

# Fetch Azure OpenAI Key
$openaiKey = az cognitiveservices account keys list --name $openaiResourceName --resource-group $resourceGroupName --query "key1" --output tsv

# Get the first Azure PostgreSQL Flexible Server in the resource group
$postgresServerName = az postgres flexible-server list --resource-group $resourceGroupName --query "[0].name" --output tsv

# Fetch PostgreSQL server fully qualified domain name
$postgresHost = az postgres flexible-server show --name $postgresServerName --resource-group $resourceGroupName --query "fullyQualifiedDomainName" --output tsv

# Fetch Entra ID access token
$token = az account get-access-token --resource-type oss-rdbms --output json | ConvertFrom-Json
$accessToken = $token.accessToken

# Print the configuration
Write-Output ""
Write-Output ""
Write-Output "AZURE_OPENAI_ENDPOINT: $openaiEndpoint"
Write-Output ""
Write-Output ""
Write-Output "AZURE_OPENAI_KEY: $openaiKey"
Write-Output ""
Write-Output ""
Write-Output "DB_CONFIG - HOST: $postgresHost"
Write-Output ""
Write-Output ""
Write-Output "DB_CONFIG - PASSWORD: $accessToken"
Write-Output ""
Write-Output ""