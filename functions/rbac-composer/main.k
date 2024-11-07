
import models.co.acme.v1alpha1 as acmev1alpha1
import models.io.upbound.azure.keyvault.v1beta1 as kvv1beta1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

keyVaultName = oxr.spec.parameters.keyVaultName
votingWebAppIdentityPrincipalId = oxr.spec.parameters.votingWebAppIdentityPrincipalId
votingCounterFunctionIdentityPrincipalId = oxr.spec.parameters.votingCounterFunctionIdentityPrincipalId

_items = []

_items += [kvv1beta1.AccessPolicy {
    metadata: _metadata('${keyVaultName}/add1')
    spec.forProvider = {
        tenantId: "get-this-somehow"
        objectId: votingWebAppIdentityPrincipalId
        secretPermissions: [
            'Get'
        ]
        keyPermissions: []
        certificatePermissions: []
    }
}]

_items += [kvv1beta1.AccessPolicy {
    metadata: _metadata('${keyVaultName}/add2')
    spec.forProvider = {
        tenantId: "get-this-somehow"
        objectId: votingCounterFunctionIdentityPrincipalId
        secretPermissions: [
            'Get'
        ]
        keyPermissions: []
        certificatePermissions: []
    }
}]


items = _items
