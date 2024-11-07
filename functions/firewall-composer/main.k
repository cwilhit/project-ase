
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

vnetName = oxr.spec.parameters.vnetName
firewallSubnetPrefix = oxr.spec.parameters.firewallSubnetPrefix
location = oxr.spec.parameters.location

# internal vars
firewallSubnetName = 'AzureFirewallSubnet'
firewallPublicIpName = 'firewallIp-'
firewallName = 'firewall-'

# Example to retrieve variables from "xr"; update as needed
# _region = "us-east-1"
# if oxr.spec?.parameters?.region:
#     _region = oxr.spec.parameters.region

_items = []

_items += [networkv1beta1.Subnet {
    metadata: _metadata("${vnetName}/${firewallSubnetName}")
    spec.forProvider = {
        addressPrefixes: [firewallSubnetPrefix]
        virtualNetworkNameSelector.matchControllerRef: True
        serviceEndpoints: [
            'Microsoft.AzureCosmosDB',
            'Microsoft.KeyVault',
            'Microsoft.ServiceBus',
            'Microsoft.Sql'
        ]
    }
}]

_items += [networkv1beta1.PublicIP {
    metadata: _metadata("${firewallPublicIpName}")
    spec.forProvider = {
        location: location
        sku: "Standard"
        allocationMethod: 'Static'
        ipVersion: 'IPv4'
        idleTimeoutInMinutes: 4
    }
}]

_items += [networkv1beta1.Firewall {
    metadata: _metadata("${firewallName}")
    spec.forProvider = {
        location: location
        threatIntelMode: 'Alert'
        ipConfiguration: [{
            name: 'clusterIpConfig'
            publicIpAddressIdSelector.matchControllerRef: True
            subnetIdSelector.matchControllerRef: True
        }]
    }
}]

_items += [networkv1beta1.FirewallNetworkRuleCollection {
    metadata: _metadata("Time")
    spec.forProvider = {
        priority: 300
        action: 'Allow'
        rule: [{
            name: 'NTP'
            protocols: [
                'Any'
            ]
            sourceAddresses: [
                '*'
            ]
            destinationAddresses: [
                '*'
            ]
            destinationPorts: [
                '123'
            ]
        }, {
            name: 'Triage'
            protocols: [
                'Any'
            ]
            sourceAddresses: [
            '*'
            ]
            destinationAddresses: [
            '*'
            ]
            destinationPorts: [
            '12000'
            ]
        }]
    }
}]

_items += [networkv1beta1.FirewallNetworkRuleCollection {
    metadata: _metadata("Time")
    spec.forProvider = {
        priority: 500
        action: 'Allow'
        rule: [{
            name: 'AzureMonitor'
            protocols: [
                'TCP'
            ]
            sourceAddresses: [
                '*'
            ]
            destinationAddresses: [
                'AzureMonitor'
            ]
            destinationPorts: [
                '80'
                '443'
            ]
        }]
    }
}]

_items += [networkv1beta1.FirewallApplicationRuleCollection {
    metadata: _metadata("AppServiceEnvironment")
    spec.forProvider = {
        priority: 500
        action: 'Allow'
        rule: [{
            name: 'AppServiceEnvironment'
            protocol: [{
                type: 'Http'
                port: 80
            }, {
                type: 'Https'
                port: 443
            }]
            fqdnTags: [
                'AppServiceEnvironment'
                'WindowsUpdate'
            ]
            sourceAddresses: [
                '*'
            ]
        }]
        
    }
}]

items = _items
