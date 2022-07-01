# dapr-azure-container-apps

Tryout dapr on azure container apps

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



## Examples

### Service invocation

#### Order Processor Service

1. Open a new terminal window and navigate to order-processor directory and install dependencies:

```
cd ./src/services/order-processor
dotnet restore
dotnet build
```

2. Run the Dotnet order-processor app with Dapr:

```
cd ./src/services/order-processor
dapr run --app-port 7001 --app-id order-processor --app-protocol http --dapr-http-port 3501 -- dotnet run
```

#### Checkout Service

1. Open a new terminal window and navigate to the checkout directory and install dependencies:

```
cd ./src/services/checkout
dotnet restore
dotnet build
```

2. Run the Dotnet checkout app with Dapr:

```
cd ./src/services/checkout
dapr run  --app-id checkout --app-protocol http --dapr-http-port 3500 -- dotnet run
```

3. Stop the Dapr service
```

```