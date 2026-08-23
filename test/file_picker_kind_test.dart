import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/services/content_types.dart';
import 'package:h3xboard/views/board_screen/components/dialogs/file_picker_kind.dart';

void main() {
  group('audioContentTypeForName', () {
    test('maps every format SoLoud can decode', () {
      expect(audioContentTypeForName('clap.mp3'), 'audio/mpeg');
      expect(audioContentTypeForName('clap.wav'), 'audio/wav');
      expect(audioContentTypeForName('clap.flac'), 'audio/flac');
      expect(audioContentTypeForName('clap.ogg'), 'audio/ogg');
      expect(audioContentTypeForName('clap.oga'), 'audio/ogg');
    });

    test('is case-insensitive, because a file picked on Windows often shouts', () {
      expect(audioContentTypeForName('CLAP.MP3'), 'audio/mpeg');
      expect(audioContentTypeForName('Clap.Wav'), 'audio/wav');
    });

    test('rejects AAC containers, which upload fine and then play silence', () {
      // SoLoud ships dr_mp3/dr_wav/dr_flac and Ogg Vorbis — there is no AAC
      // decoder. Accepting AAC would therefore produce a pad that stores a
      // perfectly valid file and makes no sound, with nothing in the UI to
      // explain why.
      expect(audioContentTypeForName('voice.m4a'), isNull);
      expect(audioContentTypeForName('voice.aac'), isNull);
    });

    test('rejects names with no extension at all', () {
      expect(audioContentTypeForName('clap'), isNull);
      expect(audioContentTypeForName(''), isNull);
    });

    test('rejects images, so a mis-set kind cannot quietly accept one', () {
      expect(audioContentTypeForName('photo.png'), isNull);
    });
  });

  group('FilePickerKind', () {
    // The native open dialog filters by extension, while the upload path decides
    // the content type from that same extension. If the two lists drift, a file
    // the dialog happily offers is uploaded as application/octet-stream. That
    // file then never appears in the picker again, because listing filters on
    // the prefix.
    for (final kind in FilePickerKind.values) {
      test('${kind.name}: every offered extension maps to its own content type', () {
        for (final extension in kind.typeGroup.extensions ?? const <String>[]) {
          final contentType = kind.contentTypeForName('sample.$extension');
          expect(
            contentType,
            isNotNull,
            reason: '.$extension is offered by the ${kind.name} open dialog but has no content type',
          );
          expect(
            contentType,
            startsWith(kind.contentTypePrefix),
            reason: '.$extension uploads as $contentType, which the ${kind.name} picker would then filter out',
          );
        }
      });
    }

    test('images and sounds accept disjoint extensions', () {
      final imageExtensions = FilePickerKind.images.typeGroup.extensions!.toSet();
      final soundExtensions = FilePickerKind.sounds.typeGroup.extensions!.toSet();
      expect(imageExtensions.intersection(soundExtensions), isEmpty);
    });

    test('each kind opens in its own folder', () {
      expect(FilePickerKind.images.defaultFolder, imagesFolder);
      expect(FilePickerKind.sounds.defaultFolder, soundsFolder);
    });
  });
}
