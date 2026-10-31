import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

class SystemStatusBanner extends StatefulWidget {
  const SystemStatusBanner({super.key});

  @override
  State<SystemStatusBanner> createState() => _SystemStatusBannerState();
}

class _SystemStatusBannerState extends State<SystemStatusBanner> {
  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
        });
      }
    });
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LocaleProvider>().strings;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _isOffline ? 24.0 : 0.0,
      width: double.infinity,
      color: Colors.redAccent.withValues(alpha: 0.9),
      child: Center(
        child: Text(
          strings.uplinkDisconnected,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontFamily: 'Courier',
          ),
        ),
      ),
    );
  }
}
