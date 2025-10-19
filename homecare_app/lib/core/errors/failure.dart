class ServerFailure implements Exception {
  final String message;
  ServerFailure(this.message);

  @override
  String toString() => 'ServerFailure: $message';
}
