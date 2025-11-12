targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Location for all resources')
@metadata({
  azd: {
    type: 'location'
    // Quota validation for OpenAI models
    usageName: [
      'OpenAI.GlobalStandard.gpt-4o,30'
      'OpenAI.GlobalStandard.text-embedding-3-small,30'
    ]
  }
})
param location string

param resourceGroupName string = ''

@description('The version of PostgreSQL to use.')
param postgresVersion string = '16'

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var prefix = '${environmentName}-${resourceToken}'
var tags = { 'azd-env-name': environmentName }

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : 'rg-${environmentName}'
  location: location
}

module azurePostgreSQLFlexibleServer 'pg.bicep' = {
  name: 'postgresql'
  scope: resourceGroup
  params: {
    name: '${prefix}-postgresql'
    location: location
    tags: tags
    postgresVersion: postgresVersion
  }
}
var azureOpenAIServiceName = '${prefix}-openai'
var embeddingDeploymentName = 'text-embedding-3-small'
var chatDeploymentName = 'gpt-4o'
module azureOpenAIService 'br/public:avm/res/cognitive-services/account:0.7.2' = {
  name: 'openai'
  scope: resourceGroup
  params: {
    name: azureOpenAIServiceName
    location: location
    tags: tags
    kind: 'OpenAI'
    customSubDomainName: azureOpenAIServiceName
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    sku: 'S0'
    deployments: [
      {
        name: chatDeploymentName
        model: {
          name: 'gpt-4o'
          version: '2024-11-20'
          format: 'OpenAI'
        }
        sku: {
          name: 'GlobalStandard'
          capacity: 30
        }
      }
      {
        name: embeddingDeploymentName
        model: {
          name: 'text-embedding-3-small'
          version: '1'
          format: 'OpenAI'
        }
        sku: {
          name: 'GlobalStandard'
          capacity: 30
        }
      }
    ]
    disableLocalAuth: true
    roleAssignments: [
      {
        principalId: deployer().objectId
        roleDefinitionIdOrName: 'Cognitive Services OpenAI User'
        principalType: 'User'
      }
    ]
  }
}

output AZURE_POSTGRES_DOMAIN string = azurePostgreSQLFlexibleServer.outputs.domain
output AZURE_POSTGRES_SERVICE string = azurePostgreSQLFlexibleServer.outputs.name
output AZURE_POSTGRES_DBNAME string = azurePostgreSQLFlexibleServer.outputs.databaseName
output AZURE_POSTGRES_USER string = deployer().userPrincipalName
output AZURE_OPENAI_SERVICE string = azureOpenAIService.name
output AZURE_OPENAI_ENDPOINT string = azureOpenAIService.outputs.endpoint
output AZURE_OPENAI_EMB_DEPLOYMENT string = embeddingDeploymentName
output AZURE_OPENAI_CHAT_DEPLOYMENT string = chatDeploymentName
