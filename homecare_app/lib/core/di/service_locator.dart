import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:homecare_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:homecare_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:homecare_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'package:homecare_app/core/constants/app_constants.dart';
import 'package:homecare_app/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:homecare_app/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:homecare_app/features/tasks/data/services/task_socket_service.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';

// Khởi tạo instance của GetIt
final sl = GetIt.instance;

// Hàm khởi tạo và đăng ký tất cả các dependency
Future<void> init() async {
  // -- Features - Auth --

  // Bloc
  // Đăng ký dạng factory, vì ta muốn có một instance mới của BLoC mỗi khi cần
  sl.registerFactory(
    () => AuthBloc(authRepository: sl()),
  );

  // Repository
  // Đăng ký dạng lazy singleton, chỉ khởi tạo khi được gọi lần đầu
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      secureStorage: sl(),
    ),
  );

  // Data Sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl()),
  );

  // -- Features - Tasks --
  sl.registerLazySingleton<TaskSocketService>(
    () => TaskSocketService(baseUrl: AppConstants.baseUrl),
  );

  sl.registerLazySingleton<TaskRemoteDataSource>(
    () => TaskRemoteDataSourceImpl(
      dio: sl(),
      baseUrl: AppConstants.baseUrl,
    ),
  );

  sl.registerLazySingleton<TaskRepository>(
    () => TaskRepositoryImpl(
      remoteDataSource: sl(),
      socketService: sl(),
    ),
  );

  // -- Core & External --

  // Dio (for networking)
  sl.registerLazySingleton(() {
    final dio = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
    // Thêm logger để debug network, chỉ trong chế độ debug
    dio.interceptors.add(PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      compact: true,
      maxWidth: 90,
    ));
    return dio;
  });

  // Flutter Secure Storage
  sl.registerLazySingleton(() => const FlutterSecureStorage());
}

Future<void> setupDependencies() => init();
