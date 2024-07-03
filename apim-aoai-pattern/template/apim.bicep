param postfix string

var region = resourceGroup().location
var logAnalyticsName = 'laws-${postfix}'
var appInsightsName = 'ai-${postfix}'
var apimName = 'apim-${postfix}'
var aoaiSpec = loadTextContent('./aoai-spec.json')
var aoaiDefaultPolicy = loadTextContent('./aoai-default-policy.xml')


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

resource aoaiApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: apiman
  name: 'openai'
  properties: {
    path: 'openai'
    subscriptionRequired: true
    protocols: [
      'https'
    ]
    type:'http'
    format: 'openapi'
    serviceUrl: json(aoaiSpec).servers[0].url
    subscriptionKeyParameterNames: {
      header: 'api-key'
    }
    value: aoaiSpec
  }

  resource policy 'policies' = {
    name: 'policy'
    properties: {
      format: 'rawxml'
      value: aoaiDefaultPolicy
    }
  }

  resource aidiag 'diagnostics' = {
    name: 'applicationinsights'
    properties: {
      loggerId: apiman::ailogger.id
      alwaysLog: 'allErrors'
      sampling: {
        samplingType: 'fixed'
        percentage: 100
      }
      logClientIp: true
      metrics: true
      verbosity: 'information'
    }
  }
}

