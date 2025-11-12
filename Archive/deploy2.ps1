$clientId = "@lab.CloudSubscription.AppId"
$clientSecret = "@lab.CloudSubscription.AppSecret"
$tenantId = "@lab.CloudSubscription.TenantId"
$subscriptionId = "@lab.CloudSubscription.Id"

# Login using Service Principal
az login --service-principal -u $clientId -p $clientSecret --tenant $tenantId --only-show-errors
az account set -s $subscriptionId --only-show-errors

# Get all deleted Cognitive Services accounts of kind OpenAI
$deletedAccounts = az cognitiveservices account list-deleted --query "[?kind=='OpenAI'].[name, location, resourceGroup]" --output tsv

foreach ($account in $deletedAccounts) {
    $parts = $account -split "`t"
    $name = $parts[0]
    $location = $parts[1]
    $resourceGroup = "@lab.CloudResourceGroup(ResourceGroup1).Name"

    az cognitiveservices account purge --name $name --location $location --resource-group $resourceGroup
}

az deployment group create --resource-group "@lab.CloudResourceGroup(ResourceGroup1).Name" --template-file "C:\Lab\infra2\deploy.bicep" --parameters restore=false --only-show-errors

$aadUserPrincipalName = "@lab.CloudPortalCredential(User1).Username"
$objectId = az ad user show --id $aadUserPrincipalName --query id --output tsv
$resourceGroupName = "@lab.CloudResourceGroup(ResourceGroup1).Name"
$server = az postgres flexible-server list --resource-group $resourceGroupName --query "[0].name" --output tsv

az postgres flexible-server microsoft-entra-admin create  --resource-group $resourceGroupName --server-name $server --display-name $aadUserPrincipalName --object-id $objectId