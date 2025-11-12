start-job -name azLogin -ScriptBlock {az login -u "@lab.CloudPortalCredential(User1).Username" -p "@lab.CloudPortalCredential(User1).Password" --only-show-errors} | Out-Null
wait-job -name azLogin | Out-Null

az account set -s "@lab.CloudSubscription.Id" --only-show-errors

az deployment group create --resource-group "@lab.CloudResourceGroup(ResourceGroup1).Name" --template-file "C:\Users\LabUser\Downloads\pg-af-agents-lab\Setup\Infra\deploy.bicep" --parameters restore=false --only-show-errors

$aadUserPrincipalName = "@lab.CloudPortalCredential(User1).Username"
$objectId = az ad user show --id $aadUserPrincipalName --query id --output tsv
$resourceGroupName = "@lab.CloudResourceGroup(ResourceGroup1).Name"
$server = az postgres flexible-server list --resource-group $resourceGroupName --query "[0].name" --output tsv

az postgres flexible-server ad-admin create --resource-group $resourceGroupName --server-name $server --display-name $aadUserPrincipalName --object-id $objectId





