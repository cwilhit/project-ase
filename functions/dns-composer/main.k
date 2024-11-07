
import models.co.acme.v1alpha1 as acmev1alpha1
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


_items = []

_items += [networkv1beta1.PrivateDNSZone {
    metadata: _metadata("todo")
}]

_items += [networkv1beta1.PrivateDNSARecord {
    metadata: _metadata("@")
    spec.forProvider = {
        zoneNameSelector.matchControllerRef: True
        ttl: 3600
        records: [
            oxr.spec.parameters.ipAddress
        ]
    }
}]

_items += [networkv1beta1.PrivateDNSARecord {
    metadata: _metadata("*")
    spec.forProvider = {
        zoneNameSelector.matchControllerRef: True
        ttl: 3600
        records: [
            oxr.spec.parameters.ipAddress
        ]
    }
}]

_items += [networkv1beta1.PrivateDNSARecord {
    metadata: _metadata("*.scm")
    spec.forProvider = {
        zoneNameSelector.matchControllerRef: True
        ttl: 3600
        records: [
            oxr.spec.parameters.ipAddress
        ]
    }
}]

_items += [networkv1beta1.PrivateDNSZoneVirtualNetworkLink {
    metadata: _metadata("dns-to-vnet-link")
    spec.forProvider = {
        registrationEnabled: False
        virtualNetworkIdSelector.matchControllerRef: True
    }
}]

items = _items
