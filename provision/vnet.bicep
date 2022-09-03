param location string = resourceGroup().location

var virtualNetworkName = '${uniqueString(resourceGroup().id)}-orderapp-vnet'
var subnetName = '${uniqueString(resourceGroup().id)}-${virtualNetworkName}-aca'


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/24'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }

  resource subnet1 'subnets' existing = {
    name: subnetName
  }

}
output subnet1ResourceId string = virtualNetwork::subnet1.id
