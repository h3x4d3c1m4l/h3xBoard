class H3xBoardApiException implements Exception {

  final int code;
  final String message;

  const H3xBoardApiException({required this.code, required this.message});

  bool get isNotFound => code == 4004;
  bool get isValidation => code == 4022;
  bool get isInternal => code == -32000;

  @override
  String toString() => 'H3xBoardApiException($code): $message';

}
