param minReplicas int = 1
param maxReplicas int = 1

param location string = resourceGroup().location
resource environment 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: 'env${uniqueString(resourceGroup().id)}' 
}
resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' existing = {
  name: 'acr${uniqueString(resourceGroup().id)}' 
}

resource checkoutapp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'checkoutapp'
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      dapr: {
        enabled: true
        appId: 'checkoutapp'
      }
      registries: [
				{
					passwordSecretRef: 'registry-password'
					server: acr.properties.loginServer
					username: acr.name
				}
			]
			secrets: [
				{
					name: 'registry-password'
					value: acr.listCredentials().passwords[0].value
				}
			]
    }
    template: {
      revisionSuffix: '4thiv3g'
      containers: [
        {
          image: '${acr.properties.loginServer}/checkout:latest'
          name: 'checkout'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}
