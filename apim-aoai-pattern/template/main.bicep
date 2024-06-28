
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

module facade 'facade.bicep' = {
  name: 'facade-pattern'
  params: {
    postfix: postfix
  }
}

module loadbalancing  'loadbalance.bicep' = {
  dependsOn: [facade]
  name: 'loadbalance-pattern'
  params: {
    postfix: postfix
  }
}
