
param region string = resourceGroup().location

param enableFacade bool = false
param enableLoadbalance bool = false
param enableBurst bool = false

var postfix = toLower(uniqueString(subscription().id, region, resourceGroup().name))

module apim 'apim.bicep' = {
  name: 'apim-core'
  params: {
    postfix: postfix
  }
}

module facade 'facade.bicep' = if(enableFacade) {
  dependsOn: [apim]
  name: 'facade-pattern'
  params: {
    postfix: postfix
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
