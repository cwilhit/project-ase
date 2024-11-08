
import models.co.acme.v1alpha1 as acmev1alpha1
import models.io.upbound.azure.network.v1beta1 as networkv1beta1
import regex
import models.io.upbound.azure.v1beta1 as v1beta1

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

_resourceId = lambda name: str -> str {
    _ocds["${name}"]?.Resource?.status?.id
}

# some vars from appgw.bicep
_appGatewayName = '${parameters.vnetName}-appgw'
_subnetNameWithoutSegment = '${_appGatewayName}-subnet'
_subnetName = '${parameters.vnetName}/${_subnetNameWithoutSegment}'
_appgwId = _resourceId(_appGatewayName)
_appgwSubnetId = _resourceId(_subnetName)
_appgwNSGName = '${parameters.vnetName}-appgw-NSG'
_appgwPublicIpAddressName = '${parameters.vnetName}-appgw-Ip'
_appGwPublicIpAddressId = _resourceId(_appgwPublicIpAddressName)
_appgwIpConfigName = '${_appGatewayName}-ipconfig'
_appgwFrontendName = '${_appGatewayName}-frontend'
_appgwBackendName = '${_appGatewayName}-backend-'
_appgwHttpSettingsName = '${_appGatewayName}-httpsettings-'
_appgwHealthProbeName = '${_appGatewayName}-healthprobe-'
_appgwListenerName = '${_appGatewayName}-listener-'
_appgwSslCertificateName = '${_appGatewayName}-ssl-'
_appgwRouteRulesName = '${_appGatewayName}-routerules-'
_appgwAutoScaleMinCapacity = 0
_appgwAutoScaleMaxCapacity = 10
_appgwZonesArray = regex.split(parameters.appgwZones, ",")

_items = []
_items += [v1beta1.ResourceGroup {
    metadata: _metadata("rg-${oxr.metadata.name}")
    spec.forProvider = {
        location: parameters.location
    }
}]


_items += [networkv1beta1.PublicIP {
    metadata: _metadata("${_appgwPublicIpAddressName}")
    spec.forProvider = {
        location: parameters.location
        sku: "Standard"
        allocationMethod: 'Static'
    }
}]

_items += [networkv1beta1.SecurityGroup {
    metadata: _metadata(_appgwNSGName)
    spec.forProvider = {
        location: parameters.location
        tags: {
            displayName: _appgwNSGName
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
            destinationAddressPrefix: parameters.subnetAddressWithPrefix
            access: 'Allow'
            priority: 202
            direction: 'Inbound'
        }]
    }
}]

_items += [networkv1beta1.Subnet {
    metadata: _metadata(_subnetName)
    spec.forProvider = {
        resourceGroupNameSelector.matchControllerRef: True
        addressPrefixes: [
            parameters.subnetAddressWithPrefix
        ]
        # networkSecurityGroup: { id: networkSecurityGroup.id, location: location }
    }
}]

_items += [networkv1beta1.SubnetNetworkSecurityGroupAssociation {
    metadata: _metadata("sga-${_subnetName}")
    spec.forProvider = {
        subnetIdSelector.matchControllerRef: True
    }
}]

_items += [networkv1beta1.ApplicationGateway {
    metadata: _metadata(_appGatewayName)
    spec.forProvider = {
        location: parameters.location
        zones: _appgwZonesArray
        tags: {}
        sku: [{
            name: 'WAF_v2'
            tier: 'WAF_v2'
        }]
        gatewayIpConfiguration: [{
            name: _appgwIpConfigName
            subnetIdSelector.matchControllerRef: True
        }]
        frontendIpConfiguration: [{
            name: _appgwFrontendName
            publicIpAddressIdSelector.matchControllerRef: True
        }]
        frontendPort: [{
            name: 'port_443'
            port: 443
        }]
        autoscaleConfiguration: [{
            minCapacity: _appgwAutoScaleMinCapacity
            maxCapacity: _appgwAutoScaleMaxCapacity
        }]
        wafConfiguration:[{
            enabled: True
            firewallMode: 'Detection'
            ruleSetType: 'OWASP'
            ruleSetVersion: '3.0'
        }]
        enableHttp2: False
        backendAddressPool: [{
            name: '${_appgwBackendName}${item.name}'
            ipAddresses: item.backendAddresses
        } for i, item in parameters.appgwApplications]
        backendHttpSettings: [{
            name: '${_appgwHttpSettingsName}${item.name}'
            port: 443
            protocol: 'Https'
            cookieBasedAffinity: 'Disabled'
            pickHostNameFromBackendAddress: True
            requestTimeout: 20
            probeName: '${_appgwId}/probes/${_appgwHealthProbeName}${item.name}'
        } for i, item in parameters.appgwApplications]
        httpListener: [{
            name: '${_appgwListenerName}${item.name}'
            frontendIpConfigurationName: '${_appgwId}/frontendIPConfigurations/${_appgwFrontendName}'
            frontendPortName: '${_appgwId}/frontendPorts/port_443'
            protocol: 'Https'
            sslCertificateName: '${_appgwId}/sslCertificates/${_appgwSslCertificateName}${item.name}'
            hostName: item.hostName
            requireSni: True
        } for i, item in parameters.appgwApplications]
        requestRoutingRule: [{
            name: '${_appgwRouteRulesName}${item.name}'
            priority: 1 # fix
            ruleType: 'Basic'
            httpListenerName:'${_appgwId}/httpListeners/${_appgwListenerName}${item.name}'
            backendAddressPoolName: '${_appgwId}/backendAddressPools/${_appgwBackendName}${item.name}'
            backendHttpSettingsName: '${_appgwId}/backendHttpSettingsCollection/${_appgwHttpSettingsName}${item.name}'
        } for i, item in parameters.appgwApplications]
        probe: [{
            name: '${_appgwHealthProbeName}${item.name}'
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
        } for i, item in parameters.appgwApplications]
        sslCertificate: [{
            name: '${_appgwSslCertificateName}${item.name}'
            dataSecretRef.name: item.certificate.data
            dataSecretRef.namespace: 'default'
            dataSecretRef.key: 'someKey'
            passwordSecretRef.name: item.certificate.password
            passwordSecretRef.key: 'someKey'
            passwordSecretRef.namespace: 'default'
        } for i, item in parameters.appgwApplications]
    }
}]

items = _items
