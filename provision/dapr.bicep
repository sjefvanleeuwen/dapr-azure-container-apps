param environment_name string
param location string = resourceGroup().location

param serviceBusNamespaceName string = 'pubsub${uniqueString(resourceGroup().id)}'
param skuName string = 'Basic'

var logAnalyticsWorkspaceName = 'logs-${environment_name}'
var appInsightsName = 'appins-${environment_name}'

@minLength(5)
@maxLength(50)
@description('Provide a globally unique name of your Azure Container Registry')
param acrName string = 'acr${uniqueString(resourceGroup().id)}'

@description('Provide a tier of your Azure Container Registry.')
param acrSku string = 'Basic'

//setup service bus
param queueNames array = [
  //'newOrder'
]

var deadLetterFirehoseQueueName = 'deadletterfirehose'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: 'Standard'
  }
}

param topics array = [
  'newOrder'
]

resource serviceBusTopics 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' =[for topic in topics : {
  parent: serviceBusNamespace
  name: topic
}]

resource deadLetterFirehoseQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' = {
  name: deadLetterFirehoseQueueName
  parent: serviceBusNamespace
  properties: {
    requiresDuplicateDetection: false
    requiresSession: false
    enablePartitioning: false
  }
}

resource queues 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' = [for queueName in queueNames: {
  parent: serviceBusNamespace
  name: queueName
  dependsOn: [
    deadLetterFirehoseQueue
  ]
  properties: {
    forwardDeadLetteredMessagesTo: deadLetterFirehoseQueueName
  }
}]


var uniqueStorageName = 'state${uniqueString(resourceGroup().id)}'
//storage account
resource mainstorage 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: uniqueStorageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource acrResource 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}

@description('Output the login server property for later use')
output loginServer string = acrResource.properties.loginServer

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

resource environment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: environment_name
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

  resource pubSubDaprComponent 'daprComponents@2022-03-01' = {
    name: 'pubsub'
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
      scopes: [
        'checkoutapp'
        'order-processor'
      ]
    }
  }

  resource daprComponent 'daprComponents@2022-03-01' = {
    name: 'statestore'
    properties: {
      componentType: 'state.azure.blobstorage'
      version: 'v1'
      ignoreErrors: false
      initTimeout: '5s'
      secrets: [
        {
          name: 'storageaccountkey'
          value: listKeys(resourceId('Microsoft.Storage/storageAccounts/', uniqueStorageName), '2021-09-01').keys[0].value
        }
      ]
      metadata: [
        {
          name: 'accountName'
          value: uniqueStorageName
        }
        {
          name: 'containerName'
          value: uniqueStorageName
        }
        {
          name: 'accountKey'
          secretRef: 'storageaccountkey'
        }
      ]
      scopes: [
        // 'checkoutapp'
        // 'order-processor'
      ]
    }
  }
}

resource checkoutapp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'checkoutapp--4thiv3g'
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
					server: acrResource.properties.loginServer
					username: acrResource.name
				}
			]
			secrets: [
				{
					name: 'registry-password'
					value: acrResource.listCredentials().passwords[0].value
				}
			]
    }
    template: {
      containers: [
        {
          image: '${acrResource.properties.loginServer}/checkout:latest'
          name: 'checkout'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  dependsOn: [
    serviceBusTopics
    orderprocessorapp
  ]
}

resource orderprocessorapp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'orderprocessorapp--3l0kxv8'
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        external: false
        targetPort: 3501
      }
      activeRevisionsMode: 'Single'
      dapr: {
        enabled: true
        appId: 'order-processor'
        appProtocol: 'http'
        appPort: 7001
      }
      registries: [
				{
					passwordSecretRef: 'registry-password'
					server: acrResource.properties.loginServer
					username: acrResource.name
				}
			]
			secrets: [
				{
					name: 'registry-password'
					value: acrResource.listCredentials().passwords[0].value
				}
			]
    }
    template: {
      containers: [
        {
          image: '${acrResource.properties.loginServer}/order:latest'
          name: 'order'
          env: [
            {
              name: 'APP_PORT'
              value: '7001'
            }
          ]
          resources: {
            cpu: json('1.0')
            memory: '2.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  dependsOn: [
    serviceBusTopics
  ]
}
