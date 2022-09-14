param minReplicas int = 1
param maxReplicas int = 1

param port int = 7001
param service string = 'order'

param location string = resourceGroup().location
resource environment 'Microsoft.App/managedEnvironments@2022-03-01' existing = {
  name: 'containerEnv${uniqueString(resourceGroup().id)}' 
}
resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' existing = {
  name: 'acr${uniqueString(resourceGroup().id)}' 
}

resource orderprocessorapp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'app-${service}'
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        external: true
        targetPort: port
      }
      activeRevisionsMode: 'Single'
      dapr: {
        enabled: true
        appId: service
        appProtocol: 'http'
        appPort: port
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
      revisionSuffix: '3l0kxv8'
      containers: [
        {
          image: '${acr.properties.loginServer}/${service}:latest'
          name: 'order'
          env: [
            {
              name: 'APP_PORT'
              value: '${port}'
            }
          ]
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
  dependsOn: [
  ]
}
