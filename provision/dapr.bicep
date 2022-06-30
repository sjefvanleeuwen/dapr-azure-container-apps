param environment_name string
param location string = 'westeurope'
param storage_account_name string
param storage_container_name string

var logAnalyticsWorkspaceName = 'logs-${environment_name}'
var appInsightsName = 'appins-${environment_name}'
