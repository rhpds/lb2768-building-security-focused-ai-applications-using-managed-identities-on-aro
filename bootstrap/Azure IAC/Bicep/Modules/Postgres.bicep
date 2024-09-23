param serverName string
param location string = resourceGroup().location
param administratorLogin string
param administratorLoginPassword string
param skuName string = 'B_Gen5_1'
param version string = '11'
param storageSizeGB int = 32

resource postgresqlServer 'Microsoft.DBforPostgreSQL/servers@2021-06-01' = {
  name: serverName
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: version
    storageProfile: {
      storageMB: storageSizeGB * 1024
    }
  }
  sku: {
    name: skuName
    tier: 'Basic'
    capacity: 1
    family: 'Gen5'
  }
}

resource firewallRule 'Microsoft.DBforPostgreSQL/servers/firewallRules@2021-06-01' = {
  name: 'AllowAllWindowsAzureIps'
  parent: postgresqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output postgresqlServerId string = postgresqlServer.id
output postgresqlServerFqdn string = postgresqlServer.properties.fullyQualifiedDomainName
