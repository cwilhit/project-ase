import models.io.upbound.azure.network.v1beta1 as networkv1beta1
import models.co.acme.v1alpha1.xprivateendpoint as acmev1alpha1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
parameters = acmev1alpha1.AcmeCoV1alpha1XPrivateEndpointSpecParameters {
    **oxr.spec.parameters
}

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

_resourceGroup = lambda -> any {
    "my-rg"
}

# used internally
_servicesSubnetName = 'services-subnet-'
_servicesNSGName = '${parameters.vnetName}-SERVICES-NSG'

_vnetId = '/subscriptions/${parameters.SubId}/resourceGroups/${_resourceGroup().name}/providers/Microsoft.Network/virtualNetworks/${parameters.vnetName}'

_sbId = '/subscriptions/${parameters.SubId}/resourceGroups/${_resourceGroup().name}/providers/Microsoft.ServiceBus/namespaces/${parameters.sbName}'
_sqlServerId = '/subscriptions/${parameters.SubId}/resourceGroups/${_resourceGroup().name}/providers/Microsoft.Sql/servers/${parameters.sqlName}'
_cosmosId = '/subscriptions/${parameters.SubId}/resourceGroups/${_resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${parameters.cosmosDBName}'
_akvId = '/subscriptions/${parameters.SubId}/resourceGroups/${_resourceGroup().name}/providers/Microsoft.KeyVault/vaults/${parameters.akvName}'

_privateEndpointSQLName = 'voting-SQL-PE-${_servicesSubnetName}'
_privateDnsZoneSQLName = 'privatelink'
_pvtEndpointDnsGroupSQLName = '${_privateEndpointSQLName}/sqldnsgroupname'


_items = []

_items += [networkv1beta1.SecurityGroup {
    metadata: _metadata("sg-${oxr.metadata.name}")
    spec.forProvider = {
        location: oxr.spec.parameters.location
        tags: {
            displayName: _servicesNSGName
        }
    }
}]

_items += [networkv1beta1.Subnet {
    metadata: _metadata("${parameters.vnetName}/${_servicesSubnetName}")
    spec.forProvider = {
        addressPrefixes: [_subnetAddressPrefix]
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
    metadata: _metadata("${_privateEndpointSQLName}")
    spec.forProvider = {
        location: oxr.spec.parameters.location
        customNetworkInterfaceName: '${_privateEndpointSQLName}-nic'
        subnetIdSelector.matchControllerRef: True
        privateServiceConnection: [{
            name: _privateEndpointSQLName
            privateConnectionResourceId: _sqlServerId

        }]
    }
}]

_items += [networkv1beta1.PrivateDNSZoneVirtualNetworkLink {
    metadata: _metadata('${_privateDnsZoneSQLName}-link')
    spec.forProvider = {
        virtualNetworkIdSelector.matchControllerRef: True
        registrationEnabled: False
    }
}]

_items += [networkv1beta1.PrivateDNSZone {
    metadata: _metadata('${_pvtEndpointDnsGroupSQLName}')
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
    metadata: _metadata("_privateEndpointSBName")
    spec.forProvider = {
        location: oxr.spec.parameters.location
        customNetworkInterfaceName: '${_privateEndpointSQLName}-nic'
        subnetIdSelector.matchControllerRef: True
        privateServiceConnection: [{
            name: _privateEndpointSQLName
            privateConnectionResourceId: _sbId
            subresourceNames: [
                'namespace'
            ]
        }]
    }
}]

_items += [networkv1beta1.PrivateDNSZone {
    metadata: _metadata('privatelink.servicebus.windows.net')
    spec.forProvider = {

    }
}]

_items += [networkv1beta1.PrivateDNSZoneVirtualNetworkLink {
    metadata: _metadata('privatelink.servicebus.windows.net-link')
    spec.forProvider = {
        virtualNetworkIdSelector.matchControllerRef: True
        privateDnsZoneNameSelector.matchControllerRef: True
        registrationEnabled: False
    }
}]

_items += [networkv1beta1.PrivateEndpoint {
    metadata: _metadata('voting-SB-PE-${_servicesSubnetName}/sbdnsgroupname')
    spec.forProvider = {
        location: oxr.spec.parameters.location
        privateDnsZoneGroup: [{
            name: 'config1'
            privateDnsZoneIdsSelector.matchControllerRef: True
        }]
    }
}]

serviceBusHostName = '.servicebus.windows.net'
privateEndpointSBName = 'voting-SB-PE-${_servicesSubnetName}'
privateDnsZoneSBName = 'privatelink${serviceBusHostName}'
pvtEndpointDnsGroupSBName = '${privateEndpointSBName}/sbdnsgroupname'

_items += [networkv1beta1.PrivateDNSARecord {
    metadata: _metadata('${privateEndpointSBName}.${privateDnsZoneSBName}')
    spec.forProvider = {
        ttl: 3600
        records: ['fix-me'] #privateEndpointSB.properties.customDnsConfigs[0].ipAddresses[0]
    }
}]

cosmosDBHostName = '.documents.azure.com'
privateEndpointCosmosName = 'voting-Cosmos-PE-${_servicesSubnetName}'
privateDnsZoneCosmosName = 'privatelink${cosmosDBHostName}'
pvtEndpointDnsGroupCosmosName = '${privateEndpointCosmosName}/sbdnsgroupname'

_items += [networkv1beta1.PrivateEndpoint {
    metadata: _metadata('voting-SB-PE-${_servicesSubnetName}/sbdnsgroupname')
    spec.forProvider = {
        location: oxr.spec.parameters.location
        subnetIdSelector.matchControllerRef: True
        privateDnsZoneGroup: [{
            name: 'config1'
            privateDnsZoneIdsSelector.matchControllerRef: True #privateDnsZoneCosmos.id
        }]
        privateServiceConnection: [{
            name: privateEndpointCosmosName
            privateConnectionResourceId: _cosmosId
            subresourceNames: [
                'Sql'
            ]
        }]
    }
}]

_items += [networkv1beta1.PrivateDNSZone {
    metadata: _metadata('${privateDnsZoneCosmosName}')
    spec.forProvider = {
    }
}]

_items += [networkv1beta1.PrivateDNSZoneVirtualNetworkLink {
    metadata: _metadata('${privateDnsZoneCosmosName}-link')
    spec.forProvider = {
        virtualNetworkIdSelector.matchControllerRef: True
        registrationEnabled: False
    }
}]

_items += [networkv1beta1.PrivateDNSARecord {
    metadata: _metadata('${privateEndpointCosmosName}.${privateDnsZoneCosmosName}')
    spec.forProvider = {
        ttl: 3600
        records: ['fix-me'] # privateEndpointCosmos.properties.customDnsConfigs[0].ipAddresses[0]
    }
}]

items = _items
