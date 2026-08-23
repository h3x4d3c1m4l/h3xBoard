class H3xBoardApiException implements Exception {

  final int code;
  final String message;

  const H3xBoardApiException({required this.code, required this.message});

  bool get isNotFound => code == 4004;
  bool get isValidation => code == 4022;
  bool get isInternal => code == -32000;

  /// The payload was refused for being too big.
  ///
  /// **Uploads always arrive as a bare 413 with no body.** The server enforces
  /// its cap at the HTTP endpoint and answers status-only on purpose. The
  /// reason is a reverse proxy in front of the server, which enforces a limit
  /// of its own and answers 413 first. That proxy's reply is an HTML error page
  /// carrying nothing this app can read. Since a message is only sometimes
  /// there, none of them are trusted: the status is what the UI acts on. See
  /// `uploadErrorText`.
  ///
  /// 4013 is the RPC-side equivalent, raised for an oversized live-share publish
  /// batch rather than for a file.
  bool get isPayloadTooLarge => code == 413 || code == 4013;

  /// The account has no storage room left for this.
  ///
  /// The opposite case to [isPayloadTooLarge] in every way that matters to a
  /// client: the file was an acceptable size, the account was not. And unlike
  /// the bodiless 413, a 507 **always carries a problem+json body** — no reverse
  /// proxy answers 507 on the server's behalf, so nothing can strip it. That
  /// body's message is a developer-facing byte count though, so the UI still
  /// says its own thing and shows the numbers through `files.v1.usage` instead.
  ///
  /// 4507 is the RPC-side equivalent; the quota is enforced on the REST upload
  /// routes, so 507 is what a client sees in practice.
  bool get isQuotaExceeded => code == 507 || code == 4507;

  @override
  String toString() => 'H3xBoardApiException($code): $message';

}
