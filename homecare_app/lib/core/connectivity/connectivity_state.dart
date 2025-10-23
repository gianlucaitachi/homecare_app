import 'package:equatable/equatable.dart';

class ConnectivityState extends Equatable {
  const ConnectivityState({required this.isOffline});

  final bool isOffline;

  ConnectivityState copyWith({bool? isOffline}) {
    return ConnectivityState(isOffline: isOffline ?? this.isOffline);
  }

  @override
  List<Object> get props => [isOffline];
}
