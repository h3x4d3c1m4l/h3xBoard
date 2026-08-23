/// Human-readable spellings of a file's size and a track's length.
///
/// Shared rather than screen-scoped because several unrelated places quote the
/// same numbers — the file picker's labels, the too-large upload message, the
/// audio player's transport, the file manager's details pane — and two spellings
/// of one number read as two different numbers.
library;

/// A file size a person can read. Public because the too-large upload message
/// quotes the server's limit in the same units the picker labels files with.
/// Reading "3.4 MB" next to "the maximum is 10.0 MB" only helps if the units match.
///
/// GB is reached only by a *total*, never by one file — the server's upload cap
/// is measured in megabytes — but the storage quota it is compared against is a
/// gibibyte by default, and "1024.0 MB of 1024.0 MB used" is a worse way to say
/// full.
String formatFileSize(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes < kb) return '$bytes B';
  if (bytes < mb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} MB';

  return '${(bytes / gb).toStringAsFixed(1)} GB';
}

/// A track length a person can read, as `m:ss`. Public for the same reason as
/// [formatFileSize]. The audio player's transport shows the length of the very
/// track the picker labelled, and two spellings of one number reads as two
/// different numbers.
String formatAudioDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
