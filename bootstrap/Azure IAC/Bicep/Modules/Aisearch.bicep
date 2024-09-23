param searchServiceName string
param location string = resourceGroup().location
param skuName string = 'basic'

resource searchService 'Microsoft.Search/searchServices@2020-08-01' = {
  name: searchServiceName
  location: location
  sku: {
    name: skuName
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
  }
}

output searchServiceId string = searchService.id
output searchServiceName string = searchService.name
output searchServiceEndpoint string = searchService.properties.hostName
