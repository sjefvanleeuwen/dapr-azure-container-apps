param location string = resourceGroup().location
param id string = uniqueString(resourceGroup().id)
param storageName string = 'statestore${uniqueString(resourceGroup().id)}'
param storageScopes array

resource stateStore 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource daprComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-03-01' = {
  name: 'env${id}/statestore'
  properties: {
    componentType: 'state.azure.blobstorage'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '5s'
    secrets: [
      {
        name: 'storageaccountkey'
        value: listKeys(resourceId('Microsoft.Storage/storageAccounts/', storageName), '2021-09-01').keys[0].value
      }
    ]
    metadata: [
      {
        name: 'accountName'
        value: storageName
      }
      {
        name: 'containerName'
        value: storageName
      }
      {
        name: 'accountKey'
        secretRef: 'storageaccountkey'
      }
    ]
    scopes: storageScopes
  }
}
