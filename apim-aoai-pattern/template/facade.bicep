param postfix string

module facades_chatcomp 'facade-operation.bicep' = {
  name: 'facade-chatcomp'
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

module facades_completion 'facade-operation.bicep' = {
  name: 'facade-completion'
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

module facades_imggen 'facade-operation.bicep' = {
  name: 'facade-imggen'
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
