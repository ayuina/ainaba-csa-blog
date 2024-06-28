param postfix string
param region string
param deployName string
param modelName string
param modelVersion string
param modelCapacity int

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: 'laws-${postfix}'
}

resource apiman 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: 'apim-${postfix}'
}

resource aoai 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: 'aoai-${postfix}-${region}'
  location: region
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: 'aoai-${postfix}-${region}'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

resource model 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: aoai
  name: deployName
  sku: {
    name: 'Standard'
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
  }
}

resource aoaiDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${aoai.name}-diag'
  scope: aoai
  properties: {
    workspaceId: logAnalytics.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: null
        categoryGroup: 'Audit'
        enabled: true
      }
      {
        category: null
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
          category: 'AllMetrics'
          enabled: true
          timeGrain: null
      }
    ]
  }
}

resource openaiContributor 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  scope: subscription()
  name: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
}


resource openaiContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =  {
  scope: aoai
  name: guid(subscription().subscriptionId, resourceGroup().name, apiman.id, aoai.id, openaiContributor.id)
  properties: {
    roleDefinitionId: openaiContributor.id
    principalId: apiman.identity.principalId
  }
}

output endpoint string = aoai.properties.endpoint
output modelDeploymentId string = model.name
