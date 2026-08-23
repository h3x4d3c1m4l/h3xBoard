/// Extension → MIME mapping for uploads.
///
/// One source of truth, because three paths need the same answer and none of
/// them can rely on the platform for it: the native open dialog reports no MIME
/// type at all, a desktop drop reports one only on some platforms, and the
/// server stores whatever the client claims. A file uploaded as the wrong type
/// is then invisible to the picker that filters on it.
library;

/// A generic type for bytes nothing more specific was recognised for. The server
/// stores it happily; the pickers filter it out, which is the intended outcome.
const String kUnknownContentType = 'application/octet-stream';

/// Maps a file name to an image MIME type for the upload's content type, or
/// `null` when the extension is not one we recognise as an image. Neither the
/// native open dialog nor a desktop drop reliably surfaces a MIME type, so the
/// extension is what both paths fall back to.
String? imageContentTypeForName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;

  return switch (name.substring(dot + 1).toLowerCase()) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'svg' => 'image/svg+xml',
    _ => null,
  };
}

/// The same mapping for audio, and the list is a **capability statement, not a
/// preference**: these are the containers SoLoud ships a decoder for. `m4a`/`aac`
/// are missing on purpose — accepting one would upload and store perfectly well
/// and then play silence, which is the least debuggable outcome available.
String? audioContentTypeForName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;

  return switch (name.substring(dot + 1).toLowerCase()) {
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'flac' => 'audio/flac',
    'ogg' || 'oga' => 'audio/ogg',
    _ => null,
  };
}

/// The best content type for [name], never null.
///
/// For callers that accept *any* file — the file manager — where an unrecognised
/// extension is a file to store, not a file to refuse. A caller that must refuse
/// unknown types asks [imageContentTypeForName] / [audioContentTypeForName]
/// directly and reads their `null` as "not this kind".
String contentTypeForFileName(String name) =>
    imageContentTypeForName(name) ?? audioContentTypeForName(name) ?? kUnknownContentType;
