
## Power Platform サブネット委任用 IaC サンプル

### main.bicep

```bicep
targetScope = 'subscription'

var basename = 'mcs2mcp-0618'
var primaryRegion = 'eastus'
var secondaryRegion = 'westus'
var powerplatEnvironmentRegion = 'unitedstates'

var primaryResourceGroupName = 'rg-${basename}-primary-${primaryRegion}'
var primaryVnetAddressPrefix = '192.168.0.0/23'
var primaryPowerPlatSubnetAddressRange = '192.168.0.0/24'
var primaryPESubnetAddressRange = '192.168.1.0/26'

var secondaryResourceGroupName = 'rg-${basename}-secondary-${secondaryRegion}'
var secondaryVnetAddressPrefix = '192.168.128.0/23'
var secondaryPowerPlatSubnetAddressRange = '192.168.128.0/24'
var secondaryPESubnetAddressRange = '192.168.129.0/26'

resource primaryResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: primaryResourceGroupName
  location: primaryRegion
}

module primary 'ppvnet.bicep' = {
  scope: primaryResourceGroup
  name: 'primary-network-resources'
  params: {
    region: primaryRegion
    vnetAddressPrefix: primaryVnetAddressPrefix
    powerplatSubnetRange: primaryPowerPlatSubnetAddressRange
    privateEndpointSubnetRange: primaryPESubnetAddressRange
  }
}

resource secondaryResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: secondaryResourceGroupName
  location: secondaryRegion
}

module secondary 'ppvnet.bicep' = {
  scope: secondaryResourceGroup
  name: 'secondary-network-resources'
  params: {
    region: secondaryRegion
    vnetAddressPrefix: secondaryVnetAddressPrefix
    powerplatSubnetRange: secondaryPowerPlatSubnetAddressRange
    privateEndpointSubnetRange: secondaryPESubnetAddressRange
  }
}


module ppenterprisePolicy 'ppentpol.bicep' = {
  scope: primaryResourceGroup
  name: 'power-platform-enterprise-policy'
  params: {
    powerplatRegion: powerplatEnvironmentRegion
    primaryVnetId: primary.outputs.vnetId
    primarySubnetName: primary.outputs.powerplatSubnetName
    secondaryVnetId: secondary.outputs.vnetId
    secondarySubnetName: secondary.outputs.powerplatSubnetName
  }
}
```

### 各リージョンにネットワークリソースを配置 : ppvnet.bicep

```bicep
param region string
param vnetAddressPrefix string
param powerplatSubnetRange string
param privateEndpointSubnetRange string

var suffix = uniqueString(subscription().id, resourceGroup().id, region)
var vnetName = 'vnet-${suffix}'
var nsgName = 'nsg-${suffix}'
var outboundPublicIpName = 'pip-${suffix}'
var outboundNatGatewayName = 'natgw-${suffix}'

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: region
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }

  resource ppsubnet 'subnets' = {
    name: 'power-platform-subnet'
    properties: {
      addressPrefix: powerplatSubnetRange
      networkSecurityGroup: {
        id: subnetNsg.id
      }
      natGateway: {
        id: outboundNatGateway.id
      }
      delegations: [
        {
          name: 'PowerPlatformDelegation'
          properties: {
            serviceName: 'Microsoft.PowerPlatform/enterprisePolicies'
          }
        }
      ]
    }
  }
  resource pesubnet 'subnets' = {
    name: 'private-endpoint-subnet'
    properties: {
      addressPrefix: privateEndpointSubnetRange
      networkSecurityGroup: {
        id: subnetNsg.id
      }
    }
  }
}

resource subnetNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: nsgName
  location: region
}

resource publicip 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: outboundPublicIpName
  location: region
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource outboundNatGateway 'Microsoft.Network/natGateways@2022-07-01' = {
  name: outboundNatGatewayName
  location: region
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: publicip.id
      }
    ]
    idleTimeoutInMinutes: 4
  }
}

output vnetId string = vnet.id
output powerplatSubnetName string = vnet::ppsubnet.name
```

### Enterprise Policy を設置する : ppentpol.bicep

```bicep
param powerplatRegion string
param primaryVnetId string
param primarySubnetName string
param secondaryVnetId string
param secondarySubnetName string

var suffix = uniqueString(subscription().id, resourceGroup().id, powerplatRegion)
var ppEntPolicyName = 'ppentpol-${suffix}'

resource powerplatEntpolicy 'Microsoft.PowerPlatform/enterprisePolicies@2020-10-30' = {
  name: ppEntPolicyName
  location: powerplatRegion
  kind: 'NetworkInjection'
  properties: {
    networkInjection:{
      virtualNetworks: [
        {
          id: primaryVnetId
          subnet: {
            name: primarySubnetName
          }
        }
        {
          id: secondaryVnetId
          subnet: {
            name: secondarySubnetName
          }
        }
      ]
    }
  }
}

output enterprisePolicyId string = powerplatEntpolicy.id
```