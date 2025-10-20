import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:homecare_app/core/constants/app_constants.dart';
import 'package:homecare_app/core/notifications/notification_service.dart';
import 'package:homecare_app/core/socket/socket_service.dart';
import 'package:homecare_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:homecare_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:homecare_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:homecare_app/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:homecare_app/features/chat/data/repositories/chat_repository.dart';
import 'package:homecare_app/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:homecare_app/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:homecare_app/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:homecare_app/features/tasks/data/services/task_socket_service.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';
import 'package:hive/hive.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

final sl = GetIt.instance;

Future<void> setupDependencies() async {
  _registerExternalDependencies();
  _registerCoreServices();
  _registerFeatureDependencies();
}

void _registerExternalDependencies() {
  sl
    ..registerLazySingleton<FlutterLocalNotificationsPlugin>(
      () => FlutterLocalNotificationsPlugin(),
    )
    ..registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(),
    )
    ..registerLazySingleton<Dio>(() {
      final dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
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
    })
    ..registerLazySingleton<SocketService>(
      () => SocketService(sl()),
    )
    ..registerLazySingleton<HiveInterface>(() => Hive);
}

void _registerCoreServices() {
  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(
      flutterLocalNotificationsPlugin: sl(),
      hive: sl(),
    ),
  );
}

void _registerFeatureDependencies() {
  // Auth
  sl
    ..registerFactory(() => AuthBloc(authRepository: sl()))
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: sl(),
        secureStorage: sl(),
      ),
    )
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(dio: sl()),
    );

  // Tasks
  sl
    ..registerLazySingleton<TaskSocketService>(
      () => TaskSocketService(baseUrl: AppConstants.baseUrl),
    )
    ..registerLazySingleton<TaskRemoteDataSource>(
      () => TaskRemoteDataSourceImpl(
        dio: sl(),
        apiBaseUrl: AppConstants.apiBaseUrl,
      ),
    )
    ..registerLazySingleton<TaskRepository>(
      () => TaskRepositoryImpl(
        remoteDataSource: sl(),
        socketService: sl(),
      ),
    )
    ..registerFactory(() => TaskBloc(notificationService: sl()));

  // Chat
  sl
    ..registerLazySingleton<ChatRemoteDataSource>(
      () => ChatRemoteDataSource(dio: sl()),
    )
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepository(remoteDataSource: sl()),
    )
    ..registerFactoryParam<ChatCubit, String, void>(
      (currentUserId, _) => ChatCubit(
        chatRepository: sl(),
        socketService: sl(),
        currentUserId: currentUserId,
      ),
    );
}
