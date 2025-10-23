import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/core/connectivity/connectivity_cubit.dart';
import 'package:homecare_app/core/connectivity/connectivity_state.dart';

class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ConnectivityCubit, ConnectivityState, bool>(
      selector: (state) => state.isOffline,
      builder: (context, isOffline) {
        if (!isOffline) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        final backgroundColor = theme.colorScheme.errorContainer;
        final foregroundColor = theme.colorScheme.onErrorContainer;
        return Material(
          color: backgroundColor,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, color: foregroundColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Offline – hiển thị dữ liệu tạm thời',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foregroundColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
