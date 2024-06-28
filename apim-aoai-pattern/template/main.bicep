
var region = resourceGroup().location
var postfix = toLower(uniqueString(subscription().id, region, resourceGroup().name))

var logAnalyticsName = 'laws-${postfix}'
var appInsightsName = 'ai-${postfix}'
var apimName = 'apim-${postfix}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: region
  properties:{
    sku:{
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: region
  kind: 'web'
  properties:{
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource apiman 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: apimName
  location: region
  sku: {
    name: 'Developer'
    capacity: 1
  }
  properties: {
    publisherName: 'contoso apim'
    publisherEmail: 'contoso-apim@example.com'
  }
  identity: { type: 'SystemAssigned' }

  resource ailogger 'loggers' = {
    name: '${appInsightsName}-logger'
    properties: {
      loggerType: 'applicationInsights'
      resourceId: appinsights.id
      credentials: {
        instrumentationKey: appinsights.properties.InstrumentationKey
      }
    }
  }
}

resource apimDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${apiman.name}-diag'
  scope: apiman
  properties: {
    workspaceId: logAnalytics.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'GatewayLogs'
        enabled: true
      }
      {
        category: 'WebSocketConnectionLogs'
        enabled: true
      }
    ]
    metrics: [
      {
         category: 'AllMetrics'
         enabled: true
      }
    ]
  }
}

module chatcomp 'aoai.bicep' = {
  name: 'chatcomp'
  params: {
    postfix: postfix
    region: 'japaneast'
    deployName: 'gpt35t'
    modelName: 'gpt-35-turbo'
    modelVersion: '0613'
    modelCapacity: 10
  }
}

resource chatcompBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apiman
  name: 'chatcomp-backend'
  properties: {
    title: chatcomp.name
    protocol: 'http'
    url: '${chatcomp.outputs.endpoint}openai'
  }
} 

module completion 'aoai.bicep' = {
  name: 'completion'
  params: {
    postfix: postfix
    region: 'swedencentral'
    deployName: 'instruct'
    modelName: 'gpt-35-turbo-instruct'
    modelVersion: '0914'
    modelCapacity: 10
  }
}

resource completionBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apiman
  name: 'completion-backend'
  properties: {
    title: completion.name
    protocol: 'http'
    url: '${completion.outputs.endpoint}openai'
  }
} 

module imggen 'aoai.bicep' = {
  name: 'imggen'
  params: {
    postfix: postfix
    region: 'australiaeast'
    deployName: 'dalle'
    modelName: 'dall-e-3'
    modelVersion: '3.0'
    modelCapacity: 1
  }
}

resource imggenBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apiman
  name: 'imggen-backend'
  properties: {
    title: imggen.name
    protocol: 'http'
    url: '${imggen.outputs.endpoint}openai'
  }
} 

