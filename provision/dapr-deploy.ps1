$params = @{
  environment_name = $CONTAINERAPPS_ENVIRONMENT
  acrName = "Dir4CbSlSkGyVEPdh8kd5w"
  location = $LOCATION
  storage_account_name =  $STORAGE_ACCOUNT
  storage_container_name = $STORAGE_ACCOUNT_CONTAINER
}

New-AzResourceGroupDeployment `
  -ResourceGroupName $RESOURCE_GROUP `
  -TemplateParameterObject $params `
  -TemplateFile ./dapr.bicep `
  -Mode "Complete" `
  -SkipTemplateParameterPrompt