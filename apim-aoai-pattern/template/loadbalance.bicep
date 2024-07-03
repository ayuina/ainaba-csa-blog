param postfix string
var regions = [ 'australiaeast', 'japaneast', 'swedencentral']

resource apiman 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: 'apim-${postfix}'

  resource aoaiApi 'apis' existing = {
    name: 'openai'

    resource chatcompops 'operations' existing = {
      name: 'ChatCompletions_Create'
    }
  }
}


module backendAoais 'aoai.bicep' = [for (region, index) in regions: {
  name: 'aoai-${index}-for-lb'
  params: {
    postfix: postfix
    region: region
    deployName: 'gpt4v'
    modelName: 'gpt-4'
    modelVersion: 'vision-preview'
    modelCapacity: 10
  }
}]

resource apimBackends 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = [for (region, index) in regions: {
  dependsOn: [ backendAoais[index] ]
  parent: apiman
  name: 'backend-aoai-${index}-for-lb'
  properties: {
    title: 'backend-aoai-${index}-for-lb'
    type: 'Single'
    protocol: 'http'
    url: 'https://aoai-${postfix}-${region}.openai.azure.com/openai'
  }
}]

resource apimBackendPool 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' =  {
  dependsOn: apimBackends
  parent: apiman
  name: 'backend-pool-for-lb'
  properties: {
    title: 'backend-pool-for-lb'
    type: 'Pool'
    pool: {
      services: [for (region, index) in regions: {
        id: resourceId('Microsoft.ApiManagement/service/backends', apiman.name, 'backend-aoai-${index}-for-lb')
      }]
    }
  }
}

resource opsPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  dependsOn: [apimBackendPool]
  parent: apiman::aoaiApi::chatcompops
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('./loadbalance-policy.xml')
  }
}
