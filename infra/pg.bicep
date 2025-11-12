param name string

param location string = resourceGroup().location

param postgresVersion string = '16' // PostgreSQL version to use

param tags object = {} // Tags to apply to the resources

@description('Creates a PostgreSQL Flexible Server.')
resource postgreSQLFlexibleServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_D2ds_v4'
    tier: 'GeneralPurpose'
  }
  properties: {    
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Disabled'
      tenantId: subscription().tenantId
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    createMode: 'Default'
    highAvailability: {
      mode: 'Disabled'
    }
    storage: {
      autoGrow: 'Disabled'
      storageSizeGB: 32
      tier: 'P10'
    }
    version: postgresVersion
  }
}


@description('Firewall rule that checks the "Allow public access from any Azure service within Azure to this server" box.')
resource allowAllAzureServicesAndResourcesWithinAzureIps 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  parent: postgreSQLFlexibleServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

@description('Firewall rule to allow all IP addresses to connect to the server. Should only be used for lab purposes.')
resource allowAll 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  name: 'AllowAll'
  parent: postgreSQLFlexibleServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

@description('Creates the "cases" database in the PostgreSQL Flexible Server.')
resource casesDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  name: 'cases'
  parent: postgreSQLFlexibleServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

@description('Configures the "azure.extensions" parameter to allowlist extensions.')
resource allowlistExtensions 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-03-01-preview' = {
  name: 'azure.extensions'
  parent: postgreSQLFlexibleServer
  dependsOn: [allowAllAzureServicesAndResourcesWithinAzureIps, allowAll, casesDatabase] // Ensure the database is created and configured before setting the parameter, as it requires a "restart."
  properties: {
    source: 'user-override'
    // TO-DO need to add pg_diskann preview for all subscriptions
    value: 'azure_ai,vector,age, pg_diskann' // Allowlist the Azure AI and vector extensions
  }
}

// This must be created *after* the server is created - it cannot be a nested child resource
resource addAddUser 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2023-03-01-preview' = {
  name: deployer().objectId // Use the deployer's principal ID as the name
  parent: postgreSQLFlexibleServer
  properties: {
    tenantId: subscription().tenantId
    principalType: 'User'
    principalName: deployer().userPrincipalName
  }
  dependsOn: [
    allowAllAzureServicesAndResourcesWithinAzureIps
    allowAll
    casesDatabase
    allowlistExtensions
  ]
}


output name string = postgreSQLFlexibleServer.name
output domain string = postgreSQLFlexibleServer.properties.fullyQualifiedDomainName
output databaseName string = casesDatabase.name
