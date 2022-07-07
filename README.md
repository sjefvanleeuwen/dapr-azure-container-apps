# dapr-azure-container-apps

Tryout dapr on azure container apps provisioning using bicep

## Prerequisites

### Create Resource

```
az group create -n dapr-aca -l westeurope
```

### Create a service principal

```
az ad sp create-for-rbac --name dapr-aca --role contributor --scopes /subscriptions/{subscription-id}/resourceGroups/dapr-aca --sdk-auth
```

output:

```
{
  "clientId": "xxxx6ddc-xxxx-xxxx-xxx-ef78a99dxxxx",
  "clientSecret": "xxxx79dc-xxxx-xxxx-xxxx-aaaaaec5xxxx",
  "subscriptionId": "xxxx251c-xxxx-xxxx-xxxx-bf99a306xxxx",
  "tenantId": "xxxx88bf-xxxx-xxxx-xxxx-2d7cd011xxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

### Create Azure Container Registry Push Principal

#### Get registry ID

```
az acr show --name <registry name> --query id --output tsv
```

#### Create container push role

```
az role assignment create --assignee <clientid> --scope <registryid> --role AcrPush
```

### Configure GitHub Secrets

Under secrets for actions in your github repository settings put your secrets:

* paste the principal json in AZURE_CREDENTIALS 
* add `dapr-aca` in AZURE_RG
* Your Subcription id in AZURE_SUBSCRIPTION
* Name of the ACRl login server. I.e.: myregistry.azurecr.io REGISTRY_LOGIN_SERVER
* ClientId of the principal REGISTRY_USERNAME
* ClientSecret of the principal REGISTRY_PASSWORD

## Examples

In the /src/services folder you can start and debug the DAPR services from VSCODE
