param location string = resourceGroup().location
param id string = uniqueString(resourceGroup().id)
param storageName string = 'statestore${uniqueString(resourceGroup().id)}'
param topics array
param pubSubScopes array
param useVnet bool
param virtualNetworkName string

resource mainstorage 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: 'pubsub${id}'
  location: location
  sku: {
    name: useVnet ? 'Premium' :  'Standard' // only premium is supported with vnet
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-11-01' existing = if(useVnet)  {
  name: virtualNetworkName
  resource subnet1 'subnets' existing = {
    name: '${virtualNetworkName}-subnet'
  }
}

resource serviceBusTopics 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' =[for topic in topics : {
  parent: serviceBusNamespace
  name: topic
}]

resource serviceBusVnetRuleSet 'Microsoft.ServiceBus/namespaces/networkRuleSets@2022-01-01-preview' = if (useVnet) {
  parent: serviceBusNamespace
  name: 'default'
  properties: {
    publicNetworkAccess: 'Enabled'
    defaultAction: 'Deny'
    virtualNetworkRules: [
      {
        subnet: {
          id: virtualNetwork::subnet1.id
        }
        ignoreMissingVnetServiceEndpoint: false
      }
    ]
  }
}

resource pubSubDaprComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-03-01' = {
  name: 'env${id}/pubsub'
  properties: {
    componentType: 'pubsub.azure.servicebus'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '5s'
    secrets: [
      {
        name: 'pubsubconnectionstring'
        value:  listKeys('${serviceBusNamespace.id}/AuthorizationRules/RootManageSharedAccessKey','2021-11-01').primaryConnectionString
      }
    ]

    metadata: [
      {
        name: 'connectionString' //Required when not using Azure Authentication.
        secretRef: 'pubsubconnectionstring'
      }
    ]
    scopes: pubSubScopes
  }
}
