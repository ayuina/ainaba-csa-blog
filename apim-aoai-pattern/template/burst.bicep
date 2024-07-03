param postfix string

resource apiman 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: 'apim-${postfix}'

  resource aoaiApi 'apis' existing = {
    name: 'openai'

    resource compops 'operations' existing = {
      name: 'Completions_Create'
    }
  }
}

//https://github.com/Azure-Samples/AI-Gateway/blob/main/labs/advanced-load-balancing/README.MD

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
  name: 'completion-burst-backend'
  properties: {
    title: completion.name
    protocol: 'http'
    url: '${completion.outputs.endpoint}openai'
    circuitBreaker: {
      rules: [
        { 
          name: 'openAiBreakerRule'
          failureCondition: {
            count: 3
            interval: 'PT5M'
            statusCodeRanges: [
              { min:429, max:429 }
            ]
          }
          tripDuration: 'PT1M'
        }
      ]
    }
  }
} 

module completionSub 'aoai.bicep' = {
  name: 'completionSub'
  params: {
    postfix: postfix
    region: 'eastus'
    deployName: 'instruct'
    modelName: 'gpt-35-turbo-instruct'
    modelVersion: '0914'
    modelCapacity: 100
  }
}

resource completionSubBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apiman
  name: 'completion-burst-backend-sub'
  properties: {
    title: completionSub.name
    protocol: 'http'
    url: '${completionSub.outputs.endpoint}openai'
  }
} 

resource completionBurstPool 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' =  {
  parent: apiman
  name: 'backend-pool-for-burst'
  properties: {
    title: 'backend-pool-for-lb'
    type: 'Pool'
    pool: {
      services: [
        {      
          id: completionBackend.id
          priority: 1
        }
        {
          id: completionSubBackend.id
          priority: 2
        }
      ]
    }
  }
}

resource opsPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  dependsOn: [completionBurstPool]
  parent: apiman::aoaiApi::compops
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('./burst-policy.xml')
  }
}

