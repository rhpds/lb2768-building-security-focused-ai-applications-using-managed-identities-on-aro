
1. Make sure Azure AI Search is configured to accept Managed Identity as well as keys.


## Create Cluster

Set Variables

```bash
UUID=9263f0b2 #$(uuidgen | tr -d '-' | head -c 8 | tr '[:upper:]' '[:lower:]')
ARO_RP_SP_OBJECT_ID=$(az ad sp list --display-name "Azure Red Hat OpenShift RP" --query '[0].id' -o tsv)
LOCATION=eastus
RESOURCEGROUP=rg-aro-miwi$UUID
DOMAIN=aro$UUID
CLUSTER=aro-miwi$UUID
VERSION=4.16.30
PULL_SECRET=$(cat pull-secret.txt)
SUBSCRIPTION=$(az account show --query id -o tsv)
```

Create RG

```
az account set --subscription "$SUBSCRIPTION"
az group create --name $RESOURCEGROUP --location $LOCATION
```

upload azuredeploy.bicep file

Create ARO Cluster

```
az deployment group create \
  --name aroDeployment \
  --resource-group $RESOURCEGROUP \
  --template-file azuredeploy.bicep \
  --parameters location=$LOCATION \
  --parameters domain=$DOMAIN \
  --parameters version=$VERSION \
  --parameters clusterName=$CLUSTER \
  --parameters rpObjectId=$ARO_RP_SP_OBJECT_ID \
  --parameters pullSecret=$PULL_SECRET
```

Log into cluster

```
oc login $(az aro show -n $CLUSTER -g $RESOURCEGROUP --query 'apiserverProfile.url' -o tsv) \
  -u kubeadmin -p $(az aro list-credentials -n $CLUSTER -g $RESOURCEGROUP --query 'kubeadminPassword' -o tsv)
```

Get kubedadmin password

```
az aro list-credentials -n $CLUSTER -g $RESOURCEGROUP --query 'kubeadminPassword' -o tsv
```

Get console url

```
az aro show \
   --name $CLUSTER \
   --resource-group $RESOURCEGROUP \
   --query "consoleProfile.url" -o tsv
```


## Perform Identity Steps

1. Set Environment Variables (change them to suit your environment)

    ```bash
    export ARO_OIDC_ISSUER="$(oc get authentication cluster -o jsonpath='{.spec.serviceAccountIssuer}')"
    export USER_ASSIGNED_IDENTITY_NAME="$RESOURCEGROUP-identity"
    export FEDERATED_IDENTITY_CREDENTIAL_NAME="$RESOURCEGROUP-federated-identity"
    export SERVICE_ACCOUNT_NAMESPACE=user
    export SERVICE_ACCOUNT_NAME="my-workbench" #"parasol"
    export LOCATION="eastus"
    export AI_SUBSCRIPTION=<SUBSCRIPTION where AI services live>
    export AI_RESOURCEGROUP="paul-ai"
    export AI_SEARCH_NAME="paul-ai"
    export AI_NAME="paul-ai"
    export AI_SEARCH_SCOPE="/subscriptions/$AI_SUBSCRIPTION/resourceGroups/$AI_RESOURCEGROUP/providers/Microsoft.Search/searchServices/$AI_SEARCH_NAME"
    export AI_SCOPE="/subscriptions/$AI_SUBSCRIPTION/resourceGroups/$AI_RESOURCEGROUP/providers/Microsoft.CognitiveServices/accounts/$AI_NAME"

    ```

1. Create the identity (you should be logged into the Subscription of the ARO Cluster)

    ```bash
    az identity create --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCEGROUP}"
    export USER_ASSIGNED_IDENTITY_OBJECT_ID="$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCEGROUP}" --query 'principalId' -otsv)"
    export USER_ASSIGNED_IDENTITY_CLIENT_ID="$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCEGROUP}" --query 'clientId' -otsv)"
    ```

1. Assign Azure AI Search RBAC role to the identity (this user doing this needs to have the necessary permissions to assign roles in the subscription with the Azure AI Services)

    ```bash
    az role assignment create --assignee-object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}" --role "Reader" \
        --scope "$AI_SEARCH_SCOPE" \
        --assignee-principal-type ServicePrincipal

    az role assignment create --assignee-object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}" --role "Search Index Data Reader" \
        --scope "$AI_SEARCH_SCOPE" \
        --assignee-principal-type ServicePrincipal

    az role assignment create --assignee-object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}" \
        --role "Cognitive Services OpenAI User" \
        --scope "$AI_SCOPE" \
        --assignee-principal-type ServicePrincipal
    ```

1. Create an Azure federated identity credential linking the service account in OpenShift Container Platform to the Azure user-assigned managed identity.

    ```bash
    az identity federated-credential create \
        --name "${FEDERATED_IDENTITY_CREDENTIAL_NAME}" \
        --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" \
        --resource-group "${RESOURCEGROUP}" \
        --issuer "${ARO_OIDC_ISSUER}" \
        --subject "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}"
    ```

1. Annotate the service account with the Azure federated identity credential:

    Run this for each workshop user

    ```bash
    oc -n $SERVICE_ACCOUNT_NAMESPACE annotate sa ${SERVICE_ACCOUNT_NAME} azure.workload.identity/client-id=${USER_ASSIGNED_IDENTITY_CLIENT_ID}
    ```

1. Label the Pod with the user

    ```bash
    oc -n $SERVICE_ACCOUNT_NAMESPACE label notebook parasol azure.workload.identity/use=true
    ```

## misc notes

```
AZURE_OPENAI_ENDPOINT=https://paul-ai.openai.azure.com/
OPENAI_API_VERSION=2024-12-01-preview
AZURE_DEPLOYMENT=gpt-4o
AZURE_EMBEDDING=text-embedding-3-small
AZURE_AI_SEARCH_SERVICE_NAME="paul-ai"
AZURE_AI_SEARCH_INDEX_NAME="paulai"
```



```
az rest --method post \
    --url https://graph.microsoft.com/beta/applications/${USER_ASSIGNED_IDENTITY_OBJECT_ID}/federatedIdentityCredentials \
    --body "{'name': '${FEDERATED_IDENTITY_CREDENTIAL_NAME}1', 'issuer': '$ARO_OIDC_ISSUER', 'audiences': ['api://AzureADTokenExchange'], 'claimsMatchingExpression': {'value': 'claims[\'sub\'] matches \'system:serviceaccount:*:${SERVICE_ACCOUNT_NAME}\'', 'languageVersion': 1}}"
```





Workbench:
standard datascience -> 2024.2


pip install https://github.com/paulczar/langchain/releases/download/azure-ai-search/langchain_community-0.3.21-py3-none-any.whl
pip install langchain-openai
pip install azure-identity
pip install azure-search-documents