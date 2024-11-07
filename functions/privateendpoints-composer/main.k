
# import models.co.acme.v1alpha1 as acmev1alpha1
# import models.io.upbound.azure.cache.v1beta1 as cachev1beta1
# import models.io.upbound.azure.cache.v1beta2 as cachev1beta2
# import models.io.upbound.azure.compute.v1beta1 as computev1beta1
# import models.io.upbound.azure.compute.v1beta2 as computev1beta2
# import models.io.upbound.azure.cosmosdb.v1beta1 as cosmosdbv1beta1
# import models.io.upbound.azure.cosmosdb.v1beta2 as cosmosdbv1beta2
# import models.io.upbound.azure.insights.v1beta1 as insightsv1beta1
# import models.io.upbound.azure.insights.v1beta2 as insightsv1beta2
# import models.io.upbound.azure.keyvault.v1beta1 as keyvaultv1beta1
# import models.io.upbound.azure.keyvault.v1beta2 as keyvaultv1beta2
import models.io.upbound.azure.network.v1beta1 as networkv1beta1
# import models.io.upbound.azure.network.v1beta2 as networkv1beta2
# import models.io.upbound.azure.operationalinsights.v1beta1 as operationalinsightsv1beta1
# import models.io.upbound.azure.operationalinsights.v1beta2 as operationalinsightsv1beta2
# import models.io.upbound.azure.servicebus.v1beta1 as servicebusv1beta1
# import models.io.upbound.azure.servicebus.v1beta2 as servicebusv1beta2
# import models.io.upbound.azure.sql.v1beta1 as sqlv1beta1
# import models.io.upbound.azure.sql.v1beta2 as sqlv1beta2
# import models.io.upbound.azure.storage.v1beta1 as storagev1beta1
# import models.io.upbound.azure.storage.v1beta2 as storagev1beta2
# import models.io.upbound.azure.v1alpha1 as azurev1alpha1
# import models.io.upbound.azure.v1beta1 as azurev1beta1
# import models.io.upbound.azure.web.v1beta1 as webv1beta1
# import models.io.upbound.azure.web.v1beta2 as webv1beta2
# import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

_resourceGroup = lambda -> any {
    "my-rg"
}

# used internally

vnetName = oxr.spec.parameters.vnetName
SubId = oxr.spec.parameters.SubId
sbName = oxr.spec.parameters.sbName
sqlName = oxr.spec.parameters.sqlName
cosmosDBName = oxr.spec.parameters.cosmosDBName
akvName = oxr.spec.parameters.akvName
subnetAddressPrefix = oxr.spec.parameters.subnetAddressPrefix

servicesSubnetName = 'services-subnet-'
servicesNSGName = '${vnetName}-SERVICES-NSG'

vnetId = '/subscriptions/${SubId}/resourceGroups/${_resourceGroup().name}/providers/Microsoft.Network/virtualNetworks/${vnetName}'

sbId = '/subscriptions/${SubId}/resourceGroups/${_resourceGroup().name}/providers/Microsoft.ServiceBus/namespaces/${sbName}'
sqlServerId = '/subscriptions/${SubId}/resourceGroups/${_resourceGroup().name}/providers/Microsoft.Sql/servers/${sqlName}'
cosmosId = '/subscriptions/${SubId}/resourceGroups/${_resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosDBName}'
akvId = '/subscriptions/${SubId}/resourceGroups/${_resourceGroup().name}/providers/Microsoft.KeyVault/vaults/${akvName}'

privateEndpointSQLName = 'voting-SQL-PE-${servicesSubnetName}'
privateDnsZoneSQLName = 'privatelink'
pvtEndpointDnsGroupSQLName = '${privateEndpointSQLName}/sqldnsgroupname'


_items = []

_items += [networkv1beta1.SecurityGroup {
    metadata: _metadata("sg-${oxr.metadata.name}")
    spec.forProvider = {
        location: oxr.spec.parameters.location
        tags: {
            displayName: servicesNSGName
        }
    }
}]

_items += [networkv1beta1.Subnet {
    metadata: _metadata("${vnetName}/${servicesSubnetName}")
    spec.forProvider = {
        addressPrefixes: [subnetAddressPrefix]
        virtualNetworkNameSelector.matchControllerRef: True
        delegation: [{
            name: 'Microsoft.Web.hostingEnvironments'
            serviceDelegation: [{
                name: 'Microsoft.Web/hostingEnvironments'
            }]
        }]
    }
}]

_items += [networkv1beta1.SubnetNetworkSecurityGroupAssociation {
    metadata: _metadata("private-sga-${oxr.metadata.name}")
    spec.forProvider = {
        subnetIdSelector.matchControllerRef: True
        networkSecurityGroupIdSelector.matchControllerRef: True
    }
}]

_items += [networkv1beta1.PrivateEndpoint {
    metadata: _metadata("${privateEndpointSQLName}")
    spec.forProvider = {
        location: oxr.spec.parameters.location
        customNetworkInterfaceName: '${privateEndpointSQLName}-nic'
        subnetIdSelector.matchControllerRef: True
        privateServiceConnection: [{
            name: privateEndpointSQLName
            privateConnectionResourceId: sqlServerId

        }]
    }
}]

_items += [networkv1beta1.PrivateDNSZoneVirtualNetworkLink {
    metadata: _metadata('${privateDnsZoneSQLName}-link')
    spec.forProvider = {
        virtualNetworkIdSelector.matchControllerRef: True
        registrationEnabled: False
    }
}]

_items += [networkv1beta1.PrivateDNSZone {
    metadata: _metadata('${pvtEndpointDnsGroupSQLName}')
    spec.forProvider = {

    }
}]

_items += [networkv1beta1.PrivateDNSARecord {
    metadata: _metadata('privateDnsZoneSQL')
    spec.forProvider = {
        ttl: 3600
        records: ['fix-me'] #privateEndpointSQL.properties.customDnsConfigs[0].ipAddresses[0]
    }
}]

_items += [networkv1beta1.PrivateEndpoint {
    metadata: _metadata("privateEndpointSBName")
    spec.forProvider = {
        location: oxr.spec.parameters.location
        customNetworkInterfaceName: '${privateEndpointSQLName}-nic'
        subnetIdSelector.matchControllerRef: True
        privateServiceConnection: [{
            name: privateEndpointSQLName
            privateConnectionResourceId: sbId

        }]
    }
}]

items = _items
