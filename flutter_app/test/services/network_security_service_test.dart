import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator_juego_responsable/services/network_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.authenticator/security');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Clean network: VPN and Proxy are false', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'checkVpnAndProxy') {
        return {
          'isVpn': false,
          'isProxy': false,
          'vpnInterface': null,
          'proxyDetails': null,
        };
      }
      return null;
    });

    final risk = await NetworkSecurityService.checkVpnAndProxy();
    expect(risk.isVpn, isFalse);
    expect(risk.isProxy, isFalse);
    expect(risk.hasNetworkAnomaly, isFalse);
  });

  test('VPN detected: isVpn is true and vpnInterface parsed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'checkVpnAndProxy') {
        return {
          'isVpn': true,
          'isProxy': false,
          'vpnInterface': 'tun0',
          'proxyDetails': null,
        };
      }
      return null;
    });

    final risk = await NetworkSecurityService.checkVpnAndProxy();
    expect(risk.isVpn, isTrue);
    expect(risk.isProxy, isFalse);
    expect(risk.vpnInterface, equals('tun0'));
    expect(risk.hasNetworkAnomaly, isTrue);
  });

  test('Proxy detected: isProxy is true and proxyDetails parsed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'checkVpnAndProxy') {
        return {
          'isVpn': false,
          'isProxy': true,
          'vpnInterface': null,
          'proxyDetails': '10.0.0.1:8080',
        };
      }
      return null;
    });

    final risk = await NetworkSecurityService.checkVpnAndProxy();
    expect(risk.isVpn, isFalse);
    expect(risk.isProxy, isTrue);
    expect(risk.proxyDetails, equals('10.0.0.1:8080'));
    expect(risk.hasNetworkAnomaly, isTrue);
  });

  test('MissingPluginException gracefully returns false anomaly', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      throw MissingPluginException();
    });

    final risk = await NetworkSecurityService.checkVpnAndProxy();
    expect(risk.isVpn, isFalse);
    expect(risk.isProxy, isFalse);
    expect(risk.hasNetworkAnomaly, isFalse);
  });
}
