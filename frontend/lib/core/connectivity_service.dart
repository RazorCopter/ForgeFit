import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_service.dart';

/// Monitora la connettività di rete e innesca la sync automatica
/// ogni volta che l'app torna online dopo un periodo offline.
class ConnectivityService {
  ConnectivityService._();

  static final ValueNotifier<bool> isOnline = ValueNotifier(true);

  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Da chiamare una sola volta in main(), prima di runApp().
  static Future<void> initialize() async {
    // Stato iniziale
    final results = await Connectivity().checkConnectivity();
    isOnline.value = _hasConnection(results);

    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final online = _hasConnection(results);
      final wasOffline = !isOnline.value;

      isOnline.value = online;

      // Sync automatica solo alla transizione offline → online
      if (online && wasOffline) {
        debugPrint('📶 [ConnectivityService] Connessione ripristinata — avvio sync');
        SyncService.syncAllPendingData();
      }

      if (!online) {
        debugPrint('📴 [ConnectivityService] Connessione persa');
      }
    });
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }
}
