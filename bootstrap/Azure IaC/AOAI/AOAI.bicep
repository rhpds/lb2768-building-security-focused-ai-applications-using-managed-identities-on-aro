param openAIServiceName string
param location string = resourceGroup().location
param skuName string = 'S0'

resource openAIService 'Microsoft.CognitiveServices/accounts@2021-10-01' = {
  name: openAIServiceName
  location: location
  kind: 'OpenAI'
  sku: {
    name: skuName
  }

  resource gpt4 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
    parent: openAIService
    name: '${openAIServiceName}GPT4'
    sku: {
      name: 'Standard'
      capacity: 10
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: 'gpt-4'
        version: '0613'
      }
      versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
      currentCapacity: 10
      raiPolicyName: 'Microsoft.Default'
    }
  }

  properties: {
    apiProperties: {
      qnaRuntimeEndpoint: 'https://<your-openai-endpoint>'
    }
  }
}

output openAIServiceId string = openAIService.id
output openAIServiceName string = openAIService.name
output openAIServiceEndpoint string = openAIService.properties.apiProperties.qnaRuntimeEndpoint
