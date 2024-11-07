
import models.co.acme.v1alpha1 as acmev1alpha1
import models.io.upbound.azure.cosmosdb.v1beta1 as cosmosdbv1beta1
import models.io.upbound.azure.sql.v1beta1 as sqlv1beta1
import models.io.upbound.azure.keyvault.v1beta1 as kvv1beta1
import models.io.upbound.azure.servicebus.v1beta1 as servicebusv1beta1
import models.io.upbound.azure.storage.v1beta1 as storagev1beta1




import regex

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

location   = oxr.spec.parameters.location 
vnetName   = oxr.spec.parameters.vnetName
sqlAdminUserName   = oxr.spec.parameters.sqlAdminUserName
sqlAdminPassword   = oxr.spec.parameters.sqlAdminPassword
sqlEntraIdAdminSid  = oxr.spec.parameters.sqlEntraIdAdminSid 
zoneRedundant  = oxr.spec.parameters.zoneRedundant 
allowedSubnetNames  = oxr.spec.parameters.allowedSubnetNames 


_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

# used internally

cosmosName = 'votingcosmos-'
cosmosDatabaseName = 'cacheDB'
cosmosContainerName = 'cacheContainer'
cosmosPartitionKeyPaths = [
  '/MessageType'
]
sqlServerName = 'sqlserver'
sqlDatabaseName = 'voting'
serviceBusName = 'votingservicebus'
serviceBusQueueName = 'votingqueue'
resourcesStorageAccountName = 'resources'
resourcesContainerName = 'rscontainer'
keyVaultName = 'akeyvault1-'
allowedSubnetNamesArray = regex.split(allowedSubnetNames, ',')

_items = []

_items += [cosmosdbv1beta1.Account {
    metadata: _metadata('${cosmosName}')
    spec.forProvider = {
        location: location
        tags: {
            defaultExperience: 'Core (SQL)'
        }
        kind: 'GlobalDocumentDB'
        publicNetworkAccessEnabled: False
        automaticFailoverEnabled: False
        enableMultipleWriteLocations: True
        isVirtualNetworkFilterEnabled: True
        offerType: 'Standard'
        consistencyPolicy: [{
            consistencyLevel: 'Session'
            maxIntervalInSeconds: 5
            maxStalenessPrefix: 100
        }]
        geoLocation: [{
            location: location
            failoverPriority: 0
            zoneRedundant: zoneRedundant
        }]
        capabilities: []
    }
}]

_items += [cosmosdbv1beta1.SQLDatabase {
    metadata: _metadata('${cosmosDatabaseName}')
    spec.forProvider = {
        accountNameSelector.matchControllerRef: True
        throughput: 400
    }
}]

_items += [cosmosdbv1beta1.SQLContainer {
    metadata: _metadata('${cosmosContainerName}')
    spec.forProvider = {
        accountNameSelector.matchControllerRef: True
        throughput: 400
        indexingPolicy: [{
            indexingMode: 'consistent'
            includedPath: [{
                path: '/*'
            }]
            excludedPath: [{
                path: '/"_etag"/?'
            }]
        }]
        partitionKeyPaths: cosmosPartitionKeyPaths
        partitionKeyKind: 'Hash'
    }
}]

_items += [sqlv1beta1.MSSQLServer {
    metadata: _metadata('${sqlServerName}')
    spec.forProvider = {
        location: location
        administratorLogin: sqlAdminUserName
        publicNetworkAccessEnabled: False
        administratorLoginPasswordSecretRef: sqlAdminPassword
        version: '12.0'
    }
}]

_items += [sqlv1beta1.MSSQLManagedDatabase {
    metadata: _metadata('managed-db')
    spec.forProvider = {
    }
}]

_items += [sqlv1beta1.MSSQLManagedInstance {
    metadata: _metadata('${sqlDatabaseName}')
    spec.forProvider = {
        location: location
        skuName: 'BC_Gen5' if zoneRedundant else 'GP_Gen5'
        collation: 'SQL_Latin1_General_CP1_CI_AS'
        storageSizeInGb: 1
        zoneRedundantEnabled: zoneRedundant
    }
}]

_items += [sqlv1beta1.MSSQLManagedInstanceActiveDirectoryAdministrator {
    metadata: _metadata('activeDirectory')
    spec.forProvider = {
        loginUsername: 'ADMIN'
        objectId: sqlEntraIdAdminSid
        tenantId: 'get-this-somehow'
        managedInstanceIdSelector.matchControllerRef: True
    }
}]

_items += [kvv1beta1.Vault {
    metadata: _metadata('${keyVaultName}')
    spec.forProvider = {
        location: location
        publicNetworkAccessEnabled: False
        skuName: 'standard'
        tenantId: 'get-this-somehow'

    }
}]

_items += [kvv1beta1.Secret {
    metadata: _metadata('CosmosKey')
    spec.forProvider = {
        keyVaultIdSelector.matchControllerRef: True
        valueSecretRef = {
            name: 'cosmos-master-key'
        }

    }
}]

_items += [kvv1beta1.Secret {
    metadata: _metadata('ServiceBusListenerConnectionString')
    spec.forProvider = {
        keyVaultIdSelector.matchControllerRef: True
        valueSecretRef = {
            name: 'ServiceBusListenerConnectionString'
            #     value: 'Endpoint=sb://${serviceBusName}.servicebus.windows.net/;SharedAccessKeyName=${serviceBusListenerSharedAccessKey.name};SharedAccessKey=${listKeys(serviceBusListenerSharedAccessKey.id, '2021-11-01').primaryKey}'
        }

    }
}]

_items += [kvv1beta1.Secret {
    metadata: _metadata('ServiceBusSenderConnectionString')
    spec.forProvider = {
        keyVaultIdSelector.matchControllerRef: True
        valueSecretRef = {
            name: 'ServiceBusSenderConnectionString'
            #    value: 'Endpoint=sb://${serviceBusName}.servicebus.windows.net/;SharedAccessKeyName=${serviceBusSenderSharedAccessKey.name};SharedAccessKey=${listKeys(serviceBusSenderSharedAccessKey.id, '2021-11-01').primaryKey}'
        }

    }
}]

_items += [servicebusv1beta1.ServiceBusNamespace {
    metadata: _metadata('${serviceBusName}')
    spec.forProvider = {
        location: location
        sku: 'Premium'
        publicNetworkAccessEnabled: False
        zoneRedundant: zoneRedundant
        capacity: 1
    }
}]

_items += [servicebusv1beta1.NamespaceAuthorizationRule {
    metadata: _metadata('ListenerSharedAccessKey')
    spec.forProvider = {
        namespaceIdSelector.matchControllerRef: True
        listen: True
    }
}]

_items += [servicebusv1beta1.NamespaceAuthorizationRule {
    metadata: _metadata('SenderSharedAccessKey')
    spec.forProvider = {
        namespaceIdSelector.matchControllerRef: True
        send: True
    }
}]

_items += [servicebusv1beta1.Queue {
    metadata: _metadata('serviceBusQueueName')
    spec.forProvider = {
        namespaceIdSelector.matchControllerRef: True
        lockDuration: 'PT1M'
        maxSizeInMegabytes: 1024
        requiresDuplicateDetection: False
        requiresSession: False
        defaultMessageTtl: 'P10675199DT2H48M5.4775807S'
        deadLetteringOnMessageExpiration: False
        enableBatchedOperations: True
        duplicateDetectionHistoryTimeWindow: 'PT10M'
        maxDeliveryCount: 10
        status: 'Active'
        autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
        enablePartitioning: False
        enableExpress: False
    }
}]

_items += [storagev1beta1.Account {
    metadata: _metadata('${resourcesStorageAccountName}')
    spec.forProvider = {
        location: location
        accountKind: 'StorageV2'
        accountTier: 'Standard'
        accessTier: 'Hot'
        accountReplicationType: 'ZRS' if zoneRedundant else 'LRS'
        publicNetworkAccessEnabled: True
    }
}]

_items += [storagev1beta1.Container {
    metadata: _metadata('${resourcesStorageAccountName}/default/${resourcesContainerName}')
    spec.forProvider = {
        containerAccessType: 'blob'
        storageAccountNameSelector.matchControllerRef: True
    }
}]

items = _items
