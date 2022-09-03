param environment_name string
param location string = resourceGroup().location

param serviceBusNamespaceName string = 'pubsub${uniqueString(resourceGroup().id)}'
// param skuName string = 'Basic'

var logAnalyticsWorkspaceName = 'loganalytics-${environment_name}'
var appInsightsName = 'appinsights-${environment_name}'

@description('The name for the Core (SQL) database')
param databaseName string = 'actorstateaccount${uniqueString(resourceGroup().id)}'


var virtualNetworkName = 'orderapp-vnet'
var subnetName = '${virtualNetworkName}-aca'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.66.0.0/22' // The environment network configuration is invalid: Provided subnet must have a size of at least /23
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.66.0.0/23' // The environment network configuration is invalid: Provided subnet must have a size of at least /23
        }
      }
    ]
  }

  resource subnet1 'subnets' existing = {
    name: subnetName
  }

}
output subnet1ResourceId string = virtualNetwork::subnet1.id


resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: 'actorstateaccount${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    enableAnalyticalStorage: false
    enableFreeTier: false
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
      }
    ]
  }
}

resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-04-15' = {
  name: '${cosmosAccount.name}/${toLower(databaseName)}'
  properties: {
    resource: {
      id: databaseName
    }
    options: {
      throughput: 400
    }
  }
}

param cosmosDbContainerName string = 'actorData'

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-10-15' = {
  name: '${cosmosDB.name}/${cosmosDbContainerName}'
    properties: {
      resource: {
        id: cosmosDbContainerName
        partitionKey: {
          paths: [
            '/id'
          ]
          kind: 'Hash'
        }
    }
  }
}

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

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  properties: {
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    zoneRedundant: false
  }
  sku: {
    name: 'Premium' // Virtual Network Rules are available only on a Premium Messaging, a Standard or Premium EventHubs namespace.
  }
}

resource serviceBusVnetRuleSet 'Microsoft.ServiceBus/namespaces/networkRuleSets@2022-01-01-preview' = {
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

// resource serviceBusVnetRules 'Microsoft.ServiceBus/namespaces/virtualnetworkrules@2018-01-01-preview' = {
//   name: 'string'
//   parent: serviceBusNamespace
//   properties: {
//     virtualNetworkSubnetId: virtualNetwork::subnet1.id
//   }
// }


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

  resource actorStateDaprComponent 'daprComponents@2022-03-01' = {
    name: 'actorstate'
    properties: {
      componentType: 'state.azure.cosmosdb'
      version: 'v1'
      ignoreErrors: false
      initTimeout: '5s'
      secrets: [
        {
          name: 'masterkeysecret'
          value: listKeys('${cosmosAccount.id}','2021-04-15').primaryMasterKey
        }
      ]
      metadata: [
        {
          name: 'url'
          value: cosmosAccount.properties.documentEndpoint
        }
        {
          name: 'masterKey'
          secretRef: 'masterkeysecret'
        }
        {
          name: 'database'
          value: databaseName
        }
        {
          name: 'collection'
          value: 'actorData'
        }
        {
          name: 'actorStateStore'
          value: 'true'
        }
      ]
      scopes: [
      ]
    }
    dependsOn: [
      cosmosDB
    ]
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
      revisionSuffix: '4thiv3g'
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
    virtualNetwork
    serviceBusTopics
    orderprocessorapp
  ]
}

resource orderprocessorapp 'Microsoft.App/containerApps@2022-03-01' = {
  name: 'orderprocessorapp'
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
      revisionSuffix: '3l0kxv8'
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
    virtualNetwork
    serviceBusTopics
  ]
}

