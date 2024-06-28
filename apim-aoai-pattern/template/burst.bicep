param postfix string

resource apiman 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: 'apim-${postfix}'
}

module completionSub 'aoai.bicep' = {
  name: 'completionSub'
  params: {
    postfix: postfix
    region: 'eastus'
    deployName: 'instruct'
    modelName: 'gpt-35-turbo-instruct'
    modelVersion: '0914'
    modelCapacity: 10
  }
}

resource completionSubBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apiman
  name: 'completion-backend-sub'
  properties: {
    title: completionSub.name
    protocol: 'http'
    url: '${completionSub.outputs.endpoint}openai'
  }
} 
