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

### Configure GitHub Secrets

Under secrets for actions in your github repository settings put your secrets:

* paste the json in AZURE_CREDENTIALS 
* add `dapr-aca` in AZURE_RG
* Your Subcription id in AZURE_SUBSCRIPTION



