
import models.co.acme.v1alpha1 as acmev1alpha1
import models.io.upbound.azure.network.v1beta1 as networkv1beta1
import regex

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
parameters = acmev1alpha1.AcmeCoV1alpha1AppGatewaySpecParameters {
    **oxr.spec.parameters
}

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

vnetName = parameters.vnetName
location = parameters.location
subnetAddressWithPrefix = parameters.subnetAddressWithPrefix
appgwZones = parameters.appgwZones
appgwApplications = parameters.appgwApplications

# some vars from appgw.bicep
appGatewayName = '${vnetName}-appgw'
subnetNameWithoutSegment = '${appGatewayName}-subnet'
subnetName = '${vnetName}/${subnetNameWithoutSegment}'
appgwId = "todo" # resourceId('Microsoft.Network/applicationGateways', appGatewayName)
appgwSubnetId = "todo" # appGatewaySubnet.id
appgwNSGName = '${vnetName}-appgw-NSG'
appgwPublicIpAddressName = '${vnetName}-appgw-Ip'
appGwPublicIpAddressId = "todo" # resourceId('Microsoft.Network/publicIPAddresses',appgwPublicIpAddressName)
appgwIpConfigName = '${appGatewayName}-ipconfig'
appgwFrontendName = '${appGatewayName}-frontend'
appgwBackendName = '${appGatewayName}-backend-'
appgwHttpSettingsName = '${appGatewayName}-httpsettings-'
appgwHealthProbeName = '${appGatewayName}-healthprobe-'
appgwListenerName = '${appGatewayName}-listener-'
appgwSslCertificateName = '${appGatewayName}-ssl-'
appgwRouteRulesName = '${appGatewayName}-routerules-'
appgwAutoScaleMinCapacity = 0
appgwAutoScaleMaxCapacity = 10
appgwZonesArray = regex.split(appgwZones, ",")

_items = []
_items += [networkv1beta1.PublicIP {
    metadata: _metadata("${vnetName}-appgw-Ip")
    spec.forProvider = {
        location: location
        sku: "Standard"
        allocationMethod: 'Static'
    }
}]

_items += [networkv1beta1.SecurityGroup {
    metadata: _metadata(appgwNSGName)
    spec.forProvider = {
        location: location
        tags: {
            displayName: appgwNSGName
        }
        securityRule = [{
            name: "APPGW-inbound-allow_infrastructure"
            description: 'Used to manage AppGW from Azure'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '65200-65535'
            sourceAddressPrefix: 'GatewayManager'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 200
            direction: 'Inbound'
        }, {
            name: "APPGW-Inbound-load-balancer"
            description: 'Allow communication from Load Balancer'
            protocol: '*'
            sourcePortRange: '*'
            destinationPortRange: '*'
            sourceAddressPrefix: 'AzureLoadBalancer'
            destinationAddressPrefix: '*'
            access: 'Allow'
            priority: 201
            direction: 'Inbound'
        }, {
            name: 'APPGW-inbound-allow_web'
            description: 'Allow web traffic from internet'
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRanges: [
                '80'
                '443'
            ]
            sourceAddressPrefix: 'Internet'
            destinationAddressPrefix: subnetAddressWithPrefix
            access: 'Allow'
            priority: 202
            direction: 'Inbound'
        }]
    }
}]

_items += [networkv1beta1.SubnetNetworkSecurityGroupAssociation {
    metadata: _metadata("sga-${oxr.metadata.name}")
    spec.forProvider = {
        subnetIdSelector.matchControllerRef: True
    }
}]


_items += [networkv1beta1.Subnet {
    metadata: _metadata(subnetName)
    spec.forProvider = {
        addressPrefixes: [
            subnetAddressWithPrefix
        ]
        virtualNetworkName: appgwNSGName
        # networkSecurityGroup: { id: networkSecurityGroup.id, location: location }
    }
}]

_items += [networkv1beta1.ApplicationGateway {
    metadata: _metadata(appGatewayName)
    spec.forProvider = {
        location: location
        zones: appgwZonesArray
        sku: [{
            name: 'WAF_v2'
            tier: 'WAF_v2'
        }]
        gatewayIpConfiguration: [{
            name: appgwIpConfigName
            subnetId: appgwSubnetId
        }]
        frontendIpConfiguration: [{
            name: appgwFrontendName
            publicIpAddressId: appGwPublicIpAddressId
        }]
        frontendPort: [{
            name: 'port_443'
            port: 443
        }]
        autoscaleConfiguration: [{
            minCapacity: appgwAutoScaleMinCapacity
            maxCapacity: appgwAutoScaleMaxCapacity
        }]
        wafConfiguration:[{
            enabled: True
            firewallMode: 'Detection'
            ruleSetType: 'OWASP'
            ruleSetVersion: '3.0'
        }]
        enableHttp2: False
        backendAddressPool: [{
            name: '${appgwBackendName}${item.name}'
            ipAddresses: item.backendAddresses
        } for i, item in appgwApplications]
        backendHttpSettings: [{
            name: '${appgwHttpSettingsName}${item.name}'
            port: 443
            protocol: 'Https'
            cookieBasedAffinity: 'Disabled'
            pickHostNameFromBackendAddress: True
            requestTimeout: 20
            probeName: '${appgwId}/probes/${appgwHealthProbeName}${item.name}'
        } for i, item in appgwApplications]
        httpListener: [{
            name: '${appgwListenerName}${item.name}'
            frontendIpConfigurationName: '${appgwId}/frontendIPConfigurations/${appgwFrontendName}'
            frontendPortName: '${appgwId}/frontendPorts/port_443'
            protocol: 'Https'
            sslCertificateName: '${appgwId}/sslCertificates/${appgwSslCertificateName}${item.name}'
            hostName: item.hostName
            requireSni: True
        } for i, item in appgwApplications]
        requestRoutingRule: [{
            name: '${appgwRouteRulesName}${item.name}'
            priority: 1 # fix
            ruleType: 'Basic'
            httpListenerName:'${appgwId}/httpListeners/${appgwListenerName}${item.name}'
            backendAddressPoolName: '${appgwId}/backendAddressPools/${appgwBackendName}${item.name}'
            backendHttpSettingsName: '${appgwId}/backendHttpSettingsCollection/${appgwHttpSettingsName}${item.name}'
        } for i, item in appgwApplications]
        probe: [{
            name: '${appgwHealthProbeName}${item.name}'
            protocol: 'Https'
            path: item.probePath
            interval: 30
            timeout: 30
            unhealthyThreshold: 3
            pickHostNameFromBackendHttpSettings: True
            minimumServers: 0
            match: [{
                statusCode: ['200-399']
            }]
        } for i, item in appgwApplications]
        sslCertificate: [{
            name: '${appgwSslCertificateName}${item.name}'
            dataSecretRef.name: item.certificate.data
            dataSecretRef.namespace: 'default'
            dataSecretRef.key: 'someKey'
            passwordSecretRef.name: item.certificate.password
            passwordSecretRef.key: 'someKey'
            passwordSecretRef.namespace: 'default'
        } for i, item in appgwApplications]
    }
}]

items = _items
