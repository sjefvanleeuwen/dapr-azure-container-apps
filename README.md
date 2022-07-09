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

## Deploying

Each example has a github action workflow associated with it. Unfortunately at this time, github does not fully support the mono repo structure, meaning that workflows are only supported from the root '~/.github/workflows folder.

In this folder you will find 

* checkout-service.yml
* order-processor.yml

The scripts can be either triggered when code in the `src/service/` specific service name path is changed, or you can startup the workflow manually upon the needed first container provisioning needed for setting up azure container apps.

###

When ACA has been deployed and the first revisions of the containers are up and running you can list them as follows:

For the checkout app:

```az containerapp revision list --name checkoutapp --resource-group dapr-aca -o table
CreatedTime                Active    Replicas    TrafficWeight    HealthState    ProvisioningState    Name
-------------------------  --------  ----------  ---------------  -------------  -------------------  --------------------
2022-07-07T20:58:52+00:00  True      1           0                Healthy        Provisioned          checkoutapp--4thiv3g
```

For the order processor app:

```az containerapp revision list --name orderprocessorapp --resource-group dapr-aca -o table
CreatedTime                Active    Replicas    TrafficWeight    HealthState    ProvisioningState    Name
-------------------------  --------  ----------  ---------------  -------------  -------------------  --------------------------
2022-07-07T20:46:50+00:00  True      1           100              Healthy        Provisioned          orderprocessorapp--3l0kxv8
```

