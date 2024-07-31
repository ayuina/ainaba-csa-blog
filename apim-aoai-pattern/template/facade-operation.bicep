param postfix string
param name string
param aoaiOpsName string
param region string
param deployName string
param modelName string
param modelVersion string
param modelCapacity int
param policy string


resource apiman 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: 'apim-${postfix}'

  resource aoaiApi 'apis' existing = {
    name: 'openai'

    resource operation 'operations' existing = {
      name: aoaiOpsName
    }
  }
}

module aoaimodel 'aoai.bicep' = {
  name: name
  params: {
    postfix: postfix
    region: region
    deployName: deployName
    modelName: modelName
    modelVersion: modelVersion
    modelCapacity: modelCapacity
  }
}

resource apimBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apiman
  name: '${name}-backend'
  properties: {
    title: name
    protocol: 'http'
    url: '${aoaimodel.outputs.endpoint}openai'
  }
}

resource opsPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  dependsOn: [aoaimodel, apimBackend]
  parent: apiman::aoaiApi::operation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: policy
  }
}
