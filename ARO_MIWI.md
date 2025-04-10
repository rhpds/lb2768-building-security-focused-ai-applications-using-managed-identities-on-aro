
1. Ensure the cluster has an OIDC Issuer configured

    ```bash
    export ARO_OIDC_ISSUER="$(oc get authentication cluster -o jsonpath='{.spec.serviceAccountIssuer}')"
    echo $ARO_OIDC_ISSUER
    ```

1. Set Environment Variables

    ```bash
    export USER_ASSIGNED_IDENTITY_NAME="user1-identity"
    export FEDERATED_IDENTITY_CREDENTIAL_NAME="user1-federated-identity"
    export SERVICE_ACCOUNT_NAMESPACE=dev
    export SERVICE_ACCOUNT_NAME="parasol"
    export RESOURCE_GROUP="rhoai-openai"
    export LOCATION="eastus2"
    ```

1. Create the identity

    ```bash
    az identity create --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}"
    export USER_ASSIGNED_IDENTITY_OBJECT_ID="$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query 'principalId' -otsv)"
    export USER_ASSIGNED_IDENTITY_CLIENT_ID="$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query 'clientId' -otsv)"
    ```

1. Assign Azure AI Search RBAC role to the identity

    ```bash
    az role assignment create --assignee-object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}" --role "Reader" \
      --scope "/subscriptions/52cc7297-fdde-4df5-bc6d-f6cca2d46aa2/resourceGroups/rhoai-openai/providers/Microsoft.Search/searchServices/rhoai-ufrqkmda" \
      --assignee-principal-type ServicePrincipal
    ```

    ```bash
    az role assignment create --assignee-object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}" --role "Search Index Data Reader" \
      --scope "/subscriptions/52cc7297-fdde-4df5-bc6d-f6cca2d46aa2/resourceGroups/rhoai-openai/providers/Microsoft.Search/searchServices/rhoai-ufrqkmda" \
      --assignee-principal-type ServicePrincipal
    ```



1. Assign Azure AI ChatGPT RBAC role to the identity

    ```bash
    az role assignment create --assignee-object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}" \
        --role "Cognitive Services OpenAI User" \
        --scope "/subscriptions/52cc7297-fdde-4df5-bc6d-f6cca2d46aa2/resourceGroups/rhoai-openai" \
        --assignee-principal-type ServicePrincipal
    ```

1. Create an Azure federated identity credential linking the service account in OpenShift Container Platform to the Azure user-assigned managed identity:

    ```bash
    az identity federated-credential create \
        --name "${FEDERATED_IDENTITY_CREDENTIAL_NAME}" \
        --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --issuer "${ARO_OIDC_ISSUER}" \
        --subject "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}"
    ```

1. Annotate the service account with the Azure federated identity credential:

    ```bash
    oc annotate sa ${SERVICE_ACCOUNT_NAME} azure.workload.identity/client-id=${USER_ASSIGNED_IDENTITY_CLIENT_ID}
    ```

1. Label the Pod with the user

    ```bash
    oc label statefulset user2 azure.workload.identity/use=true
    ```

AZURE_OPENAI_ENDPOINT=https://canadaeast.api.cognitive.microsoft.com/
OPENAI_API_VERSION=2024-05-01-preview
AZURE_DEPLOYMENT=gpt-4
AZURE_EMBEDDING=rhoai-ufrqkmda-te
AZURE_AI_SEARCH_SERVICE_NAME="rhoai-ufrqkmda"
AZURE_AI_SEARCH_INDEX_NAME="vector-1727889339723"