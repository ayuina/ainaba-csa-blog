param postfix string


resource apiman 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: 'apim-${postfix}'
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

