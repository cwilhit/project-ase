
import models.co.acme.v1alpha1 as acmev1alpha1
import models.io.upbound.azure.network.v1beta1 as networkv1beta1
import models.io.upbound.azure.v1beta1 as v1beta1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
parameters = acmev1alpha1.AcmeCoV1alpha1FirewallSpecParameters {
    **oxr.spec.parameters
}

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

_items += [networkv1beta1.Subnet {
    metadata: _metadata("AzureFirewallSubnet")
    metadata.annotations: {
        'crossplane.io/external-name': "AzureFirewallSubnet"
    }
    spec.forProvider = {
        virtualNetworkName: parameters.vnetName
        resourceGroupName: _rgName
        addressPrefixes: [parameters.firewallSubnetPrefix]
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
    metadata: _metadata("firewallIp-")
    spec.forProvider = {
        resourceGroupName: _rgName
        location: parameters.location
        sku: "Standard"
        allocationMethod: 'Static'
        ipVersion: 'IPv4'
        idleTimeoutInMinutes: 4
    }
}]

_items += [networkv1beta1.Firewall {
    metadata: _metadata("firewall-")
    spec.forProvider = {
        skuName: 'AZFW_VNet'
        skuTier: 'standard'
        resourceGroupName: _rgName
        location: parameters.location
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
        azureFirewallNameSelector.matchControllerRef: True
        resourceGroupName: _rgName
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
    metadata: _metadata("AzureMonitor")
    spec.forProvider = {
        azureFirewallNameSelector.matchControllerRef: True
        resourceGroupName: _rgName
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
        azureFirewallNameSelector.matchControllerRef: True
        resourceGroupName: _rgName
        priority: 500
        action: 'Allow'
        rule: [{
            name: 'AppServiceEnvironment'
            # protocol: [{
            #     type: 'Http'
            #     port: 80
            # }, {
            #     type: 'Https'
            #     port: 443
            # }]
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
