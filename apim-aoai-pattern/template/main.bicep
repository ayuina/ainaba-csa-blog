
var region = resourceGroup().location
var postfix = toLower(uniqueString(subscription().id, region, resourceGroup().name))

var enableFacade = false
var enableLoadbalance = false
var enableBurst = true

module apim 'apim.bicep' = {
  name: 'apim-core'
  params: {
    postfix: postfix
  }
}

module facades_chatcomp 'facade.bicep' = if(enableFacade) {
  name: 'facade-chatcomp'
  dependsOn: [apim]
  params: {
    name: 'chatcomp'
    aoaiOpsName: 'ChatCompletions_Create'
    postfix: postfix    
    region: 'japaneast'
    deployName: 'gpt35t'
    modelName: 'gpt-35-turbo'
    modelVersion: '0613'
    modelCapacity: 10
    policy: loadTextContent('./facade-chatcomp-policy.xml')
  }
}

module facades_completion 'facade.bicep' = if(enableFacade) {
  name: 'facade-completion'
  dependsOn: [apim]
  params: {
    name: 'completion'
    aoaiOpsName: 'Completions_Create'
    postfix: postfix    
    region: 'swedencentral'
    deployName: 'instruct'
    modelName: 'gpt-35-turbo-instruct'
    modelVersion: '0914'
    modelCapacity: 10
    policy: loadTextContent('./facade-completion-policy.xml')
  }
}

module facades_imggen 'facade.bicep' = if(enableFacade) {
  name: 'facade-imggen'
  dependsOn: [apim]
  params: {
    name: 'imggen'
    aoaiOpsName: 'ImageGenerations_Create'
    postfix: postfix
    region: 'australiaeast'
    deployName: 'dalle'
    modelName: 'dall-e-3'
    modelVersion: '3.0'
    modelCapacity: 1
    policy: loadTextContent('./facade-imggen-policy.xml')
  }
}

module loadbalancing  'loadbalance.bicep' = if(enableLoadbalance) {
  dependsOn: [apim]
  name: 'loadbalance-pattern'
  params: {
    postfix: postfix
  }
}


module burst  'burst.bicep' = if(enableBurst) {
  dependsOn: [apim]
  name: 'burst-pattern'
  params: {
    postfix: postfix
  }
}
