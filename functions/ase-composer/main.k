
import models.co.acme.v1alpha1 as acmev1alpha1
import models.io.upbound.azure.network.v1beta1 as networkv1beta1
import models.io.upbound.azure.network.v1beta2 as networkv1beta2
import models.io.upbound.azure.web.v1beta1 as webv1beta1
import models.io.upbound.azure.v1alpha1 as azurev1alpha1
import models.io.upbound.azure.v1beta1 as azurev1beta1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

import json

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
parameters = acmev1alpha1.AcmeCoV1alpha1ASESpecParameters {
    **oxr.spec.parameters
}

location = parameters.location
vnetName =  parameters.vnetName
vnetRouteName = parameters.vnetRouteName
aseSubnetAddressPrefix = parameters.aseSubnetAddressPrefix
dedicatedHostCount = parameters.dedicatedHostCount
zoneRedundant = parameters.zoneRedundant

# used internally
aseName = "todo" # 'ASE-${uniqueString(resourceGroup().id)}'
aseNSGName = "todo" # 'ASE-nsg-${uniqueString(resourceGroup().id)}'
aseId = oxr.metadata.name
aseSubnetName = 'ase-subnet-${aseName}-1'
aseSubnetId = "todo" # aseSubnet.id
aseLoadBalancingMode = 'Web, Publishing'

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}


_items = []

_items += [networkv1beta1.SecurityGroup {
    metadata: _metadata("sg-${oxr.metadata.name}")
    spec.forProvider = {
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
    metadata: _metadata("${vnetName}/${aseSubnetName}")
    spec.forProvider = {
        addressPrefixes: [aseSubnetAddressPrefix]
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
    metadata: _metadata("sga-${oxr.metadata.name}")
    spec.forProvider = {
        subnetIdSelector.matchControllerRef: True
    }
}]

_items += [networkv1beta1.SubnetRouteTableAssociation {
    metadata: _metadata("rta-${oxr.metadata.name}")
    spec.forProvider = {
        subnetIdSelector.matchControllerRef: True
    }
}]

_items += [{
    apiVersion: 'resources.azapi.upbound.io/v1alpha1'
    kind: 'Resource'
    metadata: _metadata('some-name')
    spec.forProvider = {
        location = parameters.location
        kind: 'ASEV3'
        body = json.encode({
            properties: {
                dedicatedHostCount: dedicatedHostCount
                zoneRedundant: zoneRedundant
                internalLoadBalancingMode: aseLoadBalancingMode
                virtualNetwork: {
                    id: aseSubnetId 
                }
            }
        })
    }
}]

items = _items
