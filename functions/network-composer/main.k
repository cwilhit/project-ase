
import models.co.acme.v1alpha1 as acmev1alpha1
import models.io.upbound.azure.compute.v1beta1 as computev1beta1
import models.io.upbound.azure.compute.v1beta2 as computev1beta2
import models.io.upbound.azure.network.v1beta1 as networkv1beta1
import models.io.upbound.azure.network.v1beta2 as networkv1beta2
import models.io.upbound.azure.v1alpha1 as azurev1alpha1
import models.io.upbound.azure.v1beta1 as azurev1beta1
import models.io.upbound.azure.web.v1beta1 as webv1beta1
import models.io.upbound.azure.web.v1beta2 as webv1beta2
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

# used internally
mustCreateVNet = False if oxr.spec.parameters.existentVnetName else True
vnetName = 'ASE-VNET' if mustCreateVNet else oxr.spec.parameters.existentVnetName
vnetRouteName = 'ASE-VNETRT'

_items = []

_items += [networkv1beta1.VirtualNetwork {
    metadata: _metadata("${vnetName}")
    spec.forProvider = {
        location: oxr.spec.parameters.location
        tags: {
            displayName: 'ASE-VNET'
        }
        addressSpace: [oxr.spec.parameters.vnetAddressPrefix]
    }
}]

_items += [networkv1beta1.RouteTable {
    metadata: _metadata("${vnetRouteName}")
    spec.forProvider = {
        location: oxr.spec.parameters.location
        tags: {
            displayName: 'UDR - Subnet'
        }
        route: [{
            name: '${vnetRouteName}-route'
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'Internet'
        }]
    }
}]

items = _items
