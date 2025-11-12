$resourceGroupName = "@lab.CloudResourceGroup(ResourceGroup1).Name"

$postgresServerName = az postgres flexible-server list --resource-group $resourceGroupName --query "[0].name" --output tsv

az postgres flexible-server parameter set --resource-group $resourceGroupName --server-name $postgresServerName --name azure.extensions --value azure_ai,pg_diskann,vector,age,azure_storage

az postgres flexible-server parameter set --resource-group $resourceGroupName --server-name $postgresServerName --name shared_preload_libraries --value age,azure_storage,pg_cron,pg_stat_statements

az postgres flexible-server restart --resource-group $resourceGroupName --name $postgresServerName