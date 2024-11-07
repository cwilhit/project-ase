
import models.co.acme.v1alpha1 as acmev1alpha1
import models.io.upbound.azure.network.v1beta1 as networkv1beta1
import models.io.upbound.azure.network.v1beta2 as networkv1beta2
import models.io.upbound.azure.v1alpha1 as azurev1alpha1
import models.io.upbound.azure.v1beta1 as azurev1beta1
import models.io.upbound.azure.compute.v1beta1 as computev1beta1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

vnetName = oxr.spec.parameters.vnetName
subnetAddressPrefix = oxr.spec.parameters.subnetAddressPrefix
location = oxr.spec.parameters.location

# used internally
computerName = 'votingjb'
jumpboxName = 'jumpbox-${computerName}'
jumpboxPublicIpName = 'jumpbox-pip-'
jumpboxSubnetName = 'jumpbox-subnet}'

jumpboxNSGName = '${vnetName}-JUMPBOX-NSG'
jumpboxNicName = 'jumpbox-nic-'

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

_items = []

_items += [networkv1beta1.PublicIP {
    metadata: _metadata("${jumpboxPublicIpName}")
    spec.forProvider = {
        location: location
        sku: "Standard"
        allocationMethod: 'Static'
    }
}]

_items += [networkv1beta1.SecurityGroup {
    metadata: _metadata("${jumpboxNSGName}")
    spec.forProvider = {
        location: oxr.spec.parameters.location
        tags: {
            displayName: jumpboxNSGName
        }
        securityRule: [{
            name: 'JUMPBOX-inbound-allow_RDP'
            description: 'Allow web traffic from app gateway'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRanges: [
                '3389'
            ]
            sourceAddressPrefix: '*'
            destinationAddressPrefix: subnetAddressPrefix
            access: 'Allow'
            priority: 100
            direction: 'Inbound'
        }]
    }
}]

_items += [networkv1beta1.Subnet {
    metadata: _metadata("${vnetName}/${jumpboxSubnetName}")
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
    metadata: _metadata("sga-${oxr.metadata.name}")
    spec.forProvider = {
        subnetIdSelector.matchControllerRef: True
    }
}]

_items += [networkv1beta1.NetworkInterface {
    metadata: _metadata("${jumpboxNicName}")
    spec.forProvider = {
        location: location
        ipConfiguration: [{
            name: 'ipconfig1'
            subnetIdSelector.matchControllerRef: True
            privateIpAddressAllocation: "Dynamic"
            publicIpAddressIdSelector.matchControllerRef: True

        }]
    }
}]

_items += [computev1beta1.WindowsVirtualMachine {
    metadata: _metadata("${jumpboxName}")
    spec.forProvider = {
        location: location
        size: 'Standard_DS2_v2'
        osDisk: [{
            caching: 'ReadWrite'
            storageAccountType: 'Standard_LRS'
        }]
        sourceImageReference: [{
            offer: 'WindowsServer'
            publisher: 'MicrosoftWindowsServer'
            sku: '2019-Datacenter-smalldisk'
            version: 'latest'
        }]
        adminPasswordSecretRef = {
            key: 'password'
            name: oxr.spec.parameters.adminPassword
            namespace: 'default'
        }
        computerName: computerName
        adminUsername: oxr.spec.parameters.adminUsername
        networkInterfaceIdsSelector.matchControllerRef: True
    }
}]

items = _items
