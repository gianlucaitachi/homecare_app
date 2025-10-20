import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:homecare_app/core/notifications/notification_service.dart';
import 'package:homecare_app/core/notifications/scheduled_notification.dart';
import 'package:homecare_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:homecare_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:homecare_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

final sl = GetIt.instance;

Future<void> setupDependencies() async {
  await _initHive();
  _registerExternalDependencies();
  _registerCoreServices();
  _registerFeatureDependencies();
}

Future<void> _initHive() async {
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(scheduledNotificationTypeId)) {
    Hive.registerAdapter(ScheduledNotificationAdapter());
  }
}

void _registerExternalDependencies() {
  sl.registerLazySingleton<Dio>(() {
    final dio = Dio();
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
      ),
    );
    return dio;
  });

  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => FlutterLocalNotificationsPlugin());
}

void _registerCoreServices() {
  sl.registerLazySingleton(
    () => NotificationService(
      flutterLocalNotificationsPlugin: sl(),
      hive: Hive,
    ),
  );
}

void _registerFeatureDependencies() {
  sl.registerFactory(() => AuthBloc(authRepository: sl()));
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      secureStorage: sl(),
    ),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl()),
  );

  sl.registerFactory(() => TaskBloc(notificationService: sl()));
}
