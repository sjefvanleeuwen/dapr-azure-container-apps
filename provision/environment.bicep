param location string = resourceGroup().location
param id string = uniqueString(resourceGroup().id)
param virtualNetworkName string = ''
param subnetName string = '${virtualNetworkName}-subnet'
param addressPrefix string = '10.66.66.0/23'
param useVnet bool= false

param logAnalyticsWorkspaceName string = 'loganalytics${id}'
param appInsightsName string = 'appinsights${id}'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-11-01' = if(useVnet) {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: addressPrefix // The environment network configuration is invalid: Provided subnet must have a size of at least /23
          serviceEndpoints:[
            {
              service: 'Microsoft.ServiceBus'
              locations: [
                '*'
              ]
            }
          ]
        }
      }
    ]
  }

  resource subnet1 'subnets' existing = {
    name: subnetName
  }

}

resource logAnalyticsWorkspace'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

// Environment with VNET
resource environmentVnet 'Microsoft.App/managedEnvironments@2022-03-01' = if (useVnet) {
  name: 'env${id}'
  location: location
  properties: {
    vnetConfiguration: {
      internal: true
      infrastructureSubnetId: virtualNetwork::subnet1.id
    }
    daprAIInstrumentationKey: reference(appInsights.id, '2020-02-02').InstrumentationKey
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspace.id, '2021-06-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspace.id, '2021-06-01').primarySharedKey
      }
    }
  }
}

// Environment without VNET
resource environment 'Microsoft.App/managedEnvironments@2022-03-01' = if (!useVnet) {
  name: 'env${id}'
  location: location
  properties: {
    daprAIInstrumentationKey: reference(appInsights.id, '2020-02-02').InstrumentationKey
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspace.id, '2021-06-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspace.id, '2021-06-01').primarySharedKey
      }
    }
  }
}
