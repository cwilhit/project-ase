
import models.co.acme.v1alpha1 as acmev1alpha1
import models.io.upbound.azure.network.v1beta1 as networkv1beta1
import models.io.upbound.azure.v1beta1 as v1beta1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
parameters = acmev1alpha1.AcmeCoV1alpha1NetworkSpecParameters {
    **oxr.spec.parameters
}

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

# used internally
_mustCreateVNet = False if parameters.existentVnetName else True
_vnetName = 'ASE-VNET' if _mustCreateVNet else parameters.existentVnetName
_vnetRouteName = 'ASE-VNETRT'

_items = []
_items += [v1beta1.ResourceGroup {
    metadata: _metadata(parameters.resourceGroup)
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

_items += [networkv1beta1.VirtualNetwork {
    metadata: _metadata("${_vnetName}")
    spec.forProvider = {
        location: parameters.location
        resourceGroupNameSelector.matchControllerRef: True
        tags: {
            displayName: 'ASE-VNET'
        }
        addressSpace: [parameters.vnetAddressPrefix]
    }
}]

_items += [networkv1beta1.RouteTable {
    metadata: _metadata("${_vnetRouteName}")
    spec.forProvider = {
        location: parameters.location
        resourceGroupNameSelector.matchControllerRef: True
        tags: {
            displayName: 'UDR - Subnet'
        }
        route: [{
            name: '${_vnetRouteName}-route'
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'Internet'
        }]
    }
}]

items = _items
