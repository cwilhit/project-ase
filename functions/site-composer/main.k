
import models.co.acme.v1alpha1 as acmev1alpha1
import models.io.upbound.azure.network.v1beta1 as networkv1beta1
import models.io.upbound.azure.cache.v1beta1 as cachev1beta1
import models.io.upbound.azure.keyvault.v1beta1 as kvv1beta1
import models.io.upbound.azure.operationalinsights.v1beta1 as oiv1beta1
import models.io.upbound.azure.insights.v1beta1 as iv1beta1
import models.io.upbound.azure.web.v1beta1 as webv1beta1




oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

vnetName = oxr.spec.parameters.vnetName
location =  oxr.spec.parameters.location
redisSubnetAddressPrefix = oxr.spec.parameters.redisSubnetAddressPrefix
zoneRedundant = oxr.spec.parameters.zoneRedundant
# used internally 

redisName = 'REDIS-'
redisSubnetName = 'redis-subnet-'
redisNSGName = '${vnetName}-REDIS-NSG'
redisSecretName = 'RedisConnectionString'
cosmosKeySecretName = 'CosmosKey'
serviceBusListenerConnectionStringSecretName = 'ServiceBusListenerConnectionString'
serviceBusSenderConnectionStringSecretName = 'ServiceBusSenderConnectionString'
votingApiName = 'votingapiapp-'
votingWebName = 'votingwebapp-'
testWebName = 'testwebapp-'
votingFunctionName = 'votingfuncapp-'
votingApiPlanName = '${votingApiName}-plan'
votingWebPlanName = '${votingWebName}-plan'
testWebPlanName = '${testWebName}-plan'
votingFunctionPlanName = '${votingFunctionName}-plan'

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

_items = []

_items += [networkv1beta1.SecurityGroup {
    metadata: _metadata("sg-${redisNSGName}")
    spec.forProvider = {
        location: location
        tags: {
            displayName: redisNSGName
        }
        securityRule: [{
            name: 'REDIS-inbound-vnet'
            description: 'Client communication inside vnet'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRanges: [
                '6379'
                '6380'
                '13000-13999'
                '15000-15999'
            ]
            sourceAddressPrefix: 'VirtualNetwork'
            destinationAddressPrefix: redisSubnetAddressPrefix
            access: 'Allow'
            priority: 200
            direction: 'Inbound'
        }, {
            name: 'REDIS-inbound-loadbalancer'
            description: 'Allow communication from Load Balancer'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: 'AzureLoadBalancer'
            destinationAddressPrefix: redisSubnetAddressPrefix
            access: 'Allow'
            priority: 201
            direction: 'Inbound'
        }, {
            name: 'REDIS-inbound-allow_internal-communication'
            description: 'Internal communications for Redis'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRanges: [
                '6379'
                '6380'
                '8443'
                '10221-10231'
                '20226'
            ]
            sourceAddressPrefix: redisSubnetAddressPrefix
            destinationAddressPrefix: redisSubnetAddressPrefix
            access: 'Allow'
            priority: 202
            direction: 'Inbound'
        }, {
            name: 'REDIS-outbound-allow_storage'
            description: 'Redis dependencies on Azure Storage/PKI (Internet)'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRanges: [
                '80'
                '443'
            ]
            sourceAddressPrefix: redisSubnetAddressPrefix
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 200
            direction: 'Outbound'
        }, {
            name: 'REDIS-outbound-allow_DNS'
            description: 'Redis dependencies on DNS (Internet/VNet)'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '53'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 201
            direction: 'Outbound'
        }, {
            name: 'REDIS-outbound-allow_ports-within-subnet'
            description: 'Internal communications for Redis'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '53'
            sourceAddressPrefix: redisSubnetAddressPrefix
            destinationAddressPrefix: redisSubnetAddressPrefix
            access: 'Allow'
            priority: 202
            direction: 'Outbound'
        }]
    }
}]

_items += [networkv1beta1.Subnet {
    metadata: _metadata("${vnetName}/${redisSubnetName}")
    spec.forProvider = {
        addressPrefixes: [redisSubnetAddressPrefix]
    }
}]

_items += [networkv1beta1.SubnetNetworkSecurityGroupAssociation {
    metadata: _metadata("site-sga-${oxr.metadata.name}")
    spec.forProvider = {
        subnetIdSelector.matchControllerRef: True
    }
}]

_items += [cachev1beta1.RedisCache {
    metadata: _metadata("-${redisName}")
    spec.forProvider = {
        location: location
        zones: ['1','2','3'] if zoneRedundant else []
        skuName: 'Premium'
        family: 'P'
        capacity: 3
        enableNonSslPort: False
        subnetIdSelector.matchControllerRef: True
    }
}]

_items += [kvv1beta1.Secret {
    metadata: _metadata("${redisSecretName}")
    spec.forProvider = {
        keyVaultIdSelector.matchControllerRef: True
        valueSecretRef = {
            name: 'secret'
            #     value: '${redisName}.redis.cache.windows.net:6380,abortConnect=false,ssl=true,password=${listKeys(redis.id, '2015-08-01').primaryKey}'

        }
    }
}]

_items += [oiv1beta1.Workspace {
    metadata: _metadata("logAnalyticsWorkspace")
    spec.forProvider = {
        location: location 
    }
}]

_items += [iv1beta1.ApplicationInsights {
    metadata: _metadata("${votingFunctionName}")
    spec.forProvider = {
        location: location 
        applicationType: 'web'
        workspaceIdSelector.matchControllerRef: True
    }
}]

_items += [iv1beta1.ApplicationInsights {
    metadata: _metadata("${votingApiName}")
    spec.forProvider = {
        location: location 
        applicationType: 'web'
        workspaceIdSelector.matchControllerRef: True
    }
}]

_items += [iv1beta1.ApplicationInsights {
    metadata: _metadata("${votingWebName}")
    spec.forProvider = {
        location: location 
        applicationType: 'web'
        workspaceIdSelector.matchControllerRef: True
    }
}]

_items += [webv1beta1.AppServicePlan {
    metadata: _metadata("${votingFunctionPlanName}")
    spec.forProvider = {
        location: location
        sku: [{
            size: 'I1V2'
            tier: 'IsolatedV2'
        }]
        kind: 'app'
        perSiteScaling: False
        reserved: False
    }
}]

_items += [webv1beta1.AppServicePlan {
    metadata: _metadata("${votingWebPlanName}")
    spec.forProvider = {
        location: location
        sku: [{
            size: 'I1V2'
            tier: 'IsolatedV2'
        }]
        kind: 'app'
        perSiteScaling: False
        reserved: False
    }
}]

_items += [webv1beta1.AppServicePlan {
    metadata: _metadata("${testWebPlanName}")
    spec.forProvider = {
        location: location
        sku: [{
            size: 'I1V2'
            tier: 'IsolatedV2'
        }]
        kind: 'app'
        perSiteScaling: False
        reserved: False
    }
}]

_items += [webv1beta1.FunctionApp {
    metadata: _metadata("${votingFunctionName}")
    spec.forProvider = {
        location: location
        identity: [{
            type: 'SystemAssigned'
        }]
        enabled: True
        appServicePlanIdSelector.matchLabels = {
            someLabel: 'voting-app'
        }
        siteConfig: [{
            alwaysOn: True
        }]
        appSettings = {
            'FUNCTIONS_EXTENSION_VERSION': '~3'
            'FUNCTIONS_WORKER_RUNTIME': 'dotnet'
            'APPINSIGHTS_INSTRUMENTATIONKEY': "key" #fix
            'APPLICATIONINSIGHTS_CONNECTION_STRING': "key" #fix
            'SERVICEBUS_CONNECTION_STRING': '' #fetch from keyvault
            'sqldb_connection': '' #fetch from SQL
        }
    }
}]

_items += [webv1beta1.LinuxWebApp {
    metadata: _metadata("${votingApiName}")
    spec.forProvider = {
        location: location
        identity: [{
            type: 'SystemAssigned'
        }]
        enabled: True
        servicePlanIdSelector.matchLabels = {
             someLabel: 'voting-api'
        }
        siteConfig: [{
            alwaysOn: True
        }]
        appSettings = {
            'APPINSIGHTS_INSTRUMENTATIONKEY': '' #fix
            'ApplicationInsights:InstrumentationKey': '' #fix
            'ConnectionStrings:SqlDbConnection': '' #fix
        }
    }
}]

_items += [webv1beta1.LinuxWebApp {
    metadata: _metadata("${votingWebName}")
    spec.forProvider = {
        location: location
        identity: [{
            type: 'SystemAssigned'
        }]
        enabled: True
        servicePlanIdSelector.matchLabels = {
             someLabel: 'voting-api'
        }
        siteConfig: [{
            alwaysOn: True
        }]
        appSettings = {
            'APPINSIGHTS_INSTRUMENTATIONKEY': '' #fix
            'ConnectionStrings:sbConnectionString': '' #fetch from SQL
            'ConnectionStrings:VotingDataAPIBaseUri': '' # fetch from 'https://${votingApiApp.properties.hostNames[0]}'
            'ApplicationInsights:InstrumentationKey': '' #fix
            'ConnectionStrings:RedisConnectionString': '' # fetch from '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${keyVaultRedisSecret.name})'
            'ConnectionStrings:queueName': 'votingqueue'
            'ConnectionStrings:CosmosUri': '' # fetch from 'https://${cosmosDbName}.documents.azure.com:443/'
            'ConnectionStrings:CosmosKey': '' # fetch from '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${cosmosKeySecretName})'
        }
    }
}]

_items += [webv1beta1.LinuxWebApp {
    metadata: _metadata("${testWebName}")
    spec.forProvider = {
        location: location
        identity: [{
            type: 'SystemAssigned'
        }]
        enabled: True
        servicePlanIdSelector.matchLabels = {
             someLabel: 'test-web'
        }
        siteConfig: [{
            alwaysOn: True
        }]
        appSettings = {
            'APPINSIGHTS_INSTRUMENTATIONKEY': '' #fix
            'ApplicationInsights:InstrumentationKey': '' #fix
        }
    }
}]

_items += [kvv1beta1.AccessPolicy {
    metadata: _metadata('add/1')
    spec.forProvider = {
        tenantId: "get-this-somehow"
        objectId: '' # votingFunction.identity.principalId
        secretPermissions: [
            'Get',
            'List'
        ]
        keyPermissions: [
            'Get',
            'List'
        ]
        certificatePermissions: []
    }
}]

_items += [kvv1beta1.AccessPolicy {
    metadata: _metadata('add/2')
    spec.forProvider = {
        tenantId: "get-this-somehow"
        objectId: '' # votingWebApp.identity.principalId
        secretPermissions: [
            'Get',
            'List'
        ]
        keyPermissions: [
            'Get',
            'List'
        ]
        certificatePermissions: []
    }
}]

_items += [kvv1beta1.AccessPolicy {
    metadata: _metadata('add/3')
    spec.forProvider = {
        tenantId: "get-this-somehow"
        objectId: '' # votingApiApp.identity.principalId
        secretPermissions: [
            'Get',
            'List'
        ]
        keyPermissions: [
            'Get',
            'List'
        ]
        certificatePermissions: []
    }
}]

_items += [kvv1beta1.AccessPolicy {
    metadata: _metadata('add/4')
    spec.forProvider = {
        tenantId: "get-this-somehow"
        objectId: '' # testWebApp.identity.principalId
        secretPermissions: [
            'Get',
            'List'
        ]
        keyPermissions: [
            'Get',
            'List'
        ]
        certificatePermissions: []
    }
}]


items = _items
