import 'dart:developer';
import 'package:flutter/services.dart';

class ClientNetworkRisk {
  final bool isVpn;
  final bool isProxy;
  final String? vpnInterface;
  final String? proxyDetails;

  const ClientNetworkRisk({
    required this.isVpn,
    required this.isProxy,
    this.vpnInterface,
    this.proxyDetails,
  });

  bool get hasNetworkAnomaly => isVpn || isProxy;

  Map<String, dynamic> toMap() {
    return {
      'isVpn': isVpn,
      'isProxy': isProxy,
      'vpnInterface': vpnInterface,
      'proxyDetails': proxyDetails,
    };
  }

  @override
  String toString() =>
      'ClientNetworkRisk(isVpn: $isVpn, isProxy: $isProxy, vpnInterface: $vpnInterface, proxyDetails: $proxyDetails)';
}

class NetworkSecurityService {
  static const MethodChannel _channel = MethodChannel('com.authenticator/security');

  static ClientNetworkRisk? _lastRisk;
  static ClientNetworkRisk? get lastRisk => _lastRisk;

  /// Detecta presencia de VPN y Proxy en el cliente Android (CU-0032).
  ///
  /// NOTA: Esta señal generada en el cliente es considerada NO CONFIABLE por el backend,
  /// ya que un atacante con cliente modificado o hookeado podría alterarla.
  static Future<ClientNetworkRisk> checkVpnAndProxy() async {
    try {
      final dynamic result = await _channel.invokeMethod('checkVpnAndProxy');
      if (result is Map) {
        final risk = ClientNetworkRisk(
          isVpn: result['isVpn'] == true,
          isProxy: result['isProxy'] == true,
          vpnInterface: result['vpnInterface'] as String?,
          proxyDetails: result['proxyDetails'] as String?,
        );
        _lastRisk = risk;
        log('CU-0032 ClientNetworkRisk: isVpn=${risk.isVpn}, isProxy=${risk.isProxy}');
        return risk;
      }
    } on MissingPluginException {
      log('CU-0032 MissingPluginException, assuming standard local network.');
    } catch (e) {
      log('CU-0032 NetworkSecurityService error: $e');
    }

    const fallback = ClientNetworkRisk(isVpn: false, isProxy: false);
    _lastRisk = fallback;
    return fallback;
  }
}
