
import models.co.acme.v1alpha1 as acmev1alpha1
import models.io.upbound.azure.network.v1beta1 as networkv1beta1
import models.io.upbound.azure.v1beta1 as v1beta1

import json

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
parameters = acmev1alpha1.AcmeCoV1alpha1ASESpecParameters {
    **oxr.spec.parameters
}

# used internally
aseNSGName = "todo" # 'ASE-nsg-${uniqueString(resourceGroup().id)}'
aseId = oxr.metadata.name
aseSubnetId = "todo" # aseSubnet.id
aseLoadBalancingMode = 'Web, Publishing'

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

_items = []
_items += [v1beta1.ResourceGroup {
    metadata: _metadata(parameters.resourceGroup)
    metadata.annotations: {
        'crossplane.io/external-name': parameters.resourceGroup
    }
    spec.managementPolicies: ['Observe']
    spec.forProvider = {
        location: parameters.location
    }
} if parameters.resourceGroup else v1beta1.ResourceGroup {
    metadata: _metadata("rg-${oxr.metadata.name}")
    spec.forProvider = {
        location: parameters.location
    }
}] 

_rgName = parameters.resourceGroup if parameters.resourceGroup else 'rg-${oxr.metadata.name}'

_items += [networkv1beta1.SecurityGroup {
    metadata: _metadata("ase-${oxr.metadata.name}")
    spec.forProvider = {
        resourceGroupName: _rgName
        location: parameters.location
        tags: {
            displayName: aseNSGName
        }
        securityRule: [{
            name: 'ASE-inbound-allow_web_traffic_from_app_gateway'
            description: 'Allow web traffic from app gateway'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRanges: [
                '80'
                '443'
            ]
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 200
            direction: 'Inbound'
        }, {
            name: 'ASE-inbound-deny-all'
            description: 'Deny all other traffic'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: '*'
            destinationAddressPrefix: '*'
            access: 'Deny'
            priority: 250
            direction: 'Inbound'
        }]
    }
}]

_items += [networkv1beta1.Subnet {
    metadata: _metadata("subnet-${parameters.vnetName}")
    spec.forProvider = {
        resourceGroupName: _rgName
        addressPrefixes: [parameters.aseSubnetAddressPrefix]
        virtualNetworkName: parameters.vnetName
        delegation: [{
            name: 'Microsoft.Web.hostingEnvironments'
            serviceDelegation: [{
                name: 'Microsoft.Web/hostingEnvironments'
            }]
        }]
    }
}]

_items += [networkv1beta1.SubnetNetworkSecurityGroupAssociation {
    metadata: _metadata("sga-${oxr.metadata.name}")
    spec.forProvider = {
        subnetIdSelector.matchControllerRef: True
        networkSecurityGroupIdSelector.matchControllerRef: True
    }
}]

_body = json.encode({
    kind: 'ASEV3'
    properties = {
        dedicatedHostCount: parameters.dedicatedHostCount
        zoneRedundant: parameters.zoneRedundant
        internalLoadBalancingMode: aseLoadBalancingMode
        virtualNetwork = {
            id: _ocds["subnet-${parameters.vnetName}"]?.Resource?.status?.atProvider?.id
        }
    }
})

_azapiRes = {
    apiVersion: 'resources.azapi.upbound.io/v1alpha1'
    kind: 'Resource'
    metadata: _metadata('ase')
    metadata.name: 'ase'
    spec.forProvider = {
        location: parameters.location
        name: 'ase'
        type: "Microsoft.Web/hostingEnvironments@2022-03-01"
        parentId: '/subscriptions/038f2b7c-3265-43b8-8624-c9ad5da610a8/resourceGroups/${_rgName}'
        body: _body
    }
}

_items += [_azapiRes]

items = _items
