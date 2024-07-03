param postfix string

resource apiman 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: 'apim-${postfix}'

  resource aoaiApi 'apis' existing = {
    name: 'openai'

    resource chatcompops 'operations' existing = {
      name: 'ChatCompletions_Create'
    }

    resource compops 'operations' existing = {
      name: 'Completions_Create'
    }

    resource imggenops 'operations' existing = {
      name: 'ImageGenerations_Create'
    }
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
