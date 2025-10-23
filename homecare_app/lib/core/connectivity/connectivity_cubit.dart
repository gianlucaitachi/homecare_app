import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'connectivity_state.dart';

class ConnectivityCubit extends Cubit<ConnectivityState> {
  ConnectivityCubit({required Connectivity connectivity})
      : _connectivity = connectivity,
        super(const ConnectivityState(isOffline: false));

  final Connectivity _connectivity;
  StreamSubscription<dynamic>? _subscription;

  Future<void> startMonitoring() async {
    await _subscription?.cancel();
    try {
      final currentStatus = await _connectivity.checkConnectivity();
      _handleStatusChange(currentStatus);
    } catch (_) {
      emit(state.copyWith(isOffline: true));
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleStatusChange,
      onError: (_) => emit(state.copyWith(isOffline: true)),
    );
  }

  void _handleStatusChange(dynamic result) {
    final results = _normalizeResult(result);
    final isOffline =
        results.isEmpty || results.every((status) => status == ConnectivityResult.none);
    if (isOffline != state.isOffline) {
      emit(state.copyWith(isOffline: isOffline));
    }
  }

  List<ConnectivityResult> _normalizeResult(dynamic result) {
    if (result is ConnectivityResult) {
      return [result];
    }
    if (result is List<ConnectivityResult>) {
      return result;
    }
    return const <ConnectivityResult>[];
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
