import 'dart:io';
import 'package:flutter/services.dart';

// Mocking RevenueCat Package for Web build compatibility
class Package {
  final String identifier;
  Package(this.identifier);
}

class IAPService {
  Future<void> initPlatformState() async {
    print("Mock IAP Service initialized.");
  }

  Future<List<Package>> getOfferings() async {
    return [
      Package('wact_starter'),
      Package('wact_growth'),
      Package('wact_dominator'),
      Package('wact_whale')
    ];
  }

  Future<bool> purchasePackage(Package package) async {
    print("Purchased mock package: \${package.identifier}");
    return true;
  }
}

final iapService = IAPService();
