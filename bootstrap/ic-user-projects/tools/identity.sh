#!/bin/bash
AI_SUBSCRIPTION=c5545383-1a94-45fe-b501-7ebdf43e5d7a
AI_RESOURCEGROUP="paul-ai"
AI_SEARCH_NAME="paul-ai"
AI_NAME="paul-ai"
AI_SEARCH_SCOPE="/subscriptions/$AI_SUBSCRIPTION/resourceGroups/$AI_RESOURCEGROUP/providers/Microsoft.Search/searchServices/$AI_SEARCH_NAME"
AI_SCOPE="/subscriptions/$AI_SUBSCRIPTION/resourceGroups/$AI_RESOURCEGROUP/providers/Microsoft.CognitiveServices/accounts/$AI_NAME"
RESOURCEGROUP=openenv-7r2kc
ARO_OIDC_ISSUER=https://eastus.oic.aro.azure.com/64dc69e4-d083-49fc-9569-ebece1dd1408/a709f46f-792e-44f0-b46b-db668bd1ad30
SERVICE_ACCOUNT_NAME=my-workbench

for COUNT in {1..5}; do
    SERVICE_ACCOUNT_NAMESPACE=user$COUNT
    USER_ASSIGNED_IDENTITY_NAME="$RESOURCEGROUP-user$COUNT-identity"
    FEDERATED_IDENTITY_CREDENTIAL_NAME="$RESOURCEGROUP-user$COUNT-federated-identity"

    az identity create --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCEGROUP}"

    USER_ASSIGNED_IDENTITY_OBJECT_ID="$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCEGROUP}" --query 'principalId' -otsv)"
    USER_ASSIGNED_IDENTITY_CLIENT_ID="$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCEGROUP}" --query 'clientId' -otsv)"

    az role assignment create --assignee-object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}" --role "Search Index Data Reader" \
        --scope "$AI_SEARCH_SCOPE" \
        --assignee-principal-type ServicePrincipal

    az role assignment create --assignee-object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}" \
        --role "Cognitive Services OpenAI User" \
        --scope "$AI_SCOPE" \
        --assignee-principal-type ServicePrincipal

    az identity federated-credential create \
        --name "${FEDERATED_IDENTITY_CREDENTIAL_NAME}" \
        --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" \
        --resource-group "${RESOURCEGROUP}" \
        --issuer "${ARO_OIDC_ISSUER}" \
        --subject "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}"
done


for COUNT in {1..5}; do
    SERVICE_ACCOUNT_NAME=my-workbench
    RESOURCEGROUP=openenv-7r2kc
    SERVICE_ACCOUNT_NAMESPACE=user$COUNT
    USER_ASSIGNED_IDENTITY_NAME="$RESOURCEGROUP-user$COUNT-identity"
    USER_ASSIGNED_IDENTITY_CLIENT_ID="$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCEGROUP}" --query 'clientId' -otsv)"
    oc -n $SERVICE_ACCOUNT_NAMESPACE annotate sa ${SERVICE_ACCOUNT_NAME} azure.workload.identity/client-id=${USER_ASSIGNED_IDENTITY_CLIENT_ID}
    oc rollout restart -n $SERVICE_ACCOUNT_NAMESPACE statefulset/my-workbench
done