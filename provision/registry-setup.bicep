param location string = resourceGroup().location

@minLength(5)
@maxLength(50)
@description('Provide a globally unique name of your Azure Container Registry')
param acrName string = 'acr${uniqueString(resourceGroup().id)}'

@description('Provide a tier of your Azure Container Registry.')
param acrSku string = 'Basic'

resource acrResource 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  properties: {
    publicNetworkAccess: 'Disabled'
  }
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  // properties: {
  //   adminUserEnabled: true
  // }
}
