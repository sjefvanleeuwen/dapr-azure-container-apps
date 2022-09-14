param environment_name string
param location string = resourceGroup().location

param serviceBusNamespaceName string = 'pubsub${uniqueString(resourceGroup().id)}'
// param skuName string = 'Basic'

var logAnalyticsWorkspaceName = 'loganalytics-${environment_name}'
var appInsightsName = 'appinsights-${environment_name}'

@description('The name for the Core (SQL) database')
param databaseName string = 'actorstateaccount${uniqueString(resourceGroup().id)}'

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

