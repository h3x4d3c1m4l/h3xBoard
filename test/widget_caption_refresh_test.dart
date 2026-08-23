import 'package:flutter_test/flutter_test.dart';
import 'package:h3xboard/models/board_content.dart';
import 'package:h3xboard/models/board_widget.dart';
import 'package:h3xboard/views/base/build_context_accessor.dart';
import 'package:h3xboard/views/board_screen/board_screen_view_model.dart';

/// Keeping widget captions in step with the files they name.
///
/// A pad's label and a player's title are snapshots of the file name, taken
/// when the file was picked. They are stored rather than looked up because
/// mirrors never see file metadata: the name has to travel with the config.
/// That snapshot goes stale the moment the file is renamed, and this is what
/// closes the gap on load.
void main() {
  BoardWidget widget(String id, BoardWidgetConfig config) => BoardWidget(id: id, config: config, x: 0, y: 0);

  // The accessor is never touched by a caption refresh: it reads and rewrites
  // the widget list and nothing else.
  BoardScreenViewModel modelWith(List<BoardWidget> widgets) =>
      BoardScreenViewModel(contextAccessor: BuildContextAccessor())
        ..setInitialContent(BoardContent(widgets: widgets));

  group('caption source', () {
    test('a pad and a player caption themselves from a file', () {
      expect(boardWidgetCaptionFileId(const SoundPadConfig(fileId: 'f1')), 'f1');
      expect(boardWidgetCaptionFileId(const AudioPlayerConfig(fileId: 'f2')), 'f2');
    });

    test('a widget with no file chosen yet has no caption to refresh', () {
      expect(boardWidgetCaptionFileId(const SoundPadConfig()), isNull);
      expect(boardWidgetCaptionFileId(const AudioPlayerConfig()), isNull);
    });

    test('an image and a clock have bytes or none, but never a caption', () {
      // Renaming an image's file changes nothing on screen, so asking for its
      // metadata on every load would be a round trip for nothing.
      expect(boardWidgetCaptionFileId(const ImageConfig(fileId: 'f3')), isNull);
      expect(boardWidgetCaptionFileId(const DigitalClockConfig()), isNull);
    });
  });

  group('deriving a caption', () {
    test('drops the extension', () {
      expect(captionForFileName('applause.mp3'), 'applause');
    });

    test('keeps a name that has none', () {
      expect(captionForFileName('applause'), 'applause');
    });

    test('keeps a dotfile whole rather than blanking it', () {
      expect(captionForFileName('.hidden'), '.hidden');
    });

    test('has nothing to offer for a missing name', () {
      expect(captionForFileName(null), isEmpty);
      expect(captionForFileName(''), isEmpty);
    });
  });

  group('refreshing a board', () {
    test('re-labels a pad whose file was renamed', () {
      final model = modelWith([widget('w1', const SoundPadConfig(fileId: 'f1', label: 'applause'))]);

      final changed = model.refreshWidgetCaptions({'f1': 'crowd-cheer.mp3'});

      expect(changed, isTrue);
      expect((model.boardWidgets.single.config as SoundPadConfig).label, 'crowd-cheer');
    });

    test('re-titles a player whose file was renamed', () {
      final model = modelWith([widget('w1', const AudioPlayerConfig(fileId: 'f1', title: 'intro'))]);

      final changed = model.refreshWidgetCaptions({'f1': 'closing-theme.mp3'});

      expect(changed, isTrue);
      expect((model.boardWidgets.single.config as AudioPlayerConfig).title, 'closing-theme');
    });

    test('reports no change when every name still matches', () {
      // The ordinary case, on every single board open. It must not look like an
      // edit, or opening a board would dirty it.
      final model = modelWith([widget('w1', const SoundPadConfig(fileId: 'f1', label: 'applause'))]);

      expect(model.refreshWidgetCaptions({'f1': 'applause.mp3'}), isFalse);
    });

    test('leaves a widget alone when its file did not come back', () {
      // A file the server skipped is deleted, not renamed. Blanking the caption
      // would throw away the only clue about what the pad used to point at.
      final model = modelWith([widget('w1', const SoundPadConfig(fileId: 'gone', label: 'applause'))]);

      final changed = model.refreshWidgetCaptions({'other': 'something.mp3'});

      expect(changed, isFalse);
      expect((model.boardWidgets.single.config as SoundPadConfig).label, 'applause');
    });

    test('touches only the widgets whose names moved', () {
      final model = modelWith([
        widget('w1', const SoundPadConfig(fileId: 'f1', label: 'applause')),
        widget('w2', const AudioPlayerConfig(fileId: 'f2', title: 'intro')),
        widget('w3', const ImageConfig(fileId: 'f3')),
      ]);

      final changed = model.refreshWidgetCaptions({'f1': 'applause.mp3', 'f2': 'closing-theme.mp3'});

      expect(changed, isTrue);
      expect((model.boardWidgets[0].config as SoundPadConfig).label, 'applause');
      expect((model.boardWidgets[1].config as AudioPlayerConfig).title, 'closing-theme');
      expect(model.boardWidgets[2].config, const ImageConfig(fileId: 'f3'));
    });

    test('two pads sharing one file both follow it', () {
      // Nothing stops a board pointing two widgets at the same sound.
      final model = modelWith([
        widget('w1', const SoundPadConfig(fileId: 'f1', label: 'applause')),
        widget('w2', const SoundPadConfig(fileId: 'f1', label: 'applause')),
      ])..refreshWidgetCaptions({'f1': 'crowd-cheer.mp3'});

      final labels = model.boardWidgets.map((bw) => (bw.config as SoundPadConfig).label);
      expect(labels, ['crowd-cheer', 'crowd-cheer']);
    });

    test('keeps everything about the widget except the caption', () {
      const config = SoundPadConfig(fileId: 'f1', label: 'applause', emoji: '👏', volume: 0.5, triggerSeed: 3);
      final model = modelWith([widget('w1', config)])..refreshWidgetCaptions({'f1': 'crowd-cheer.mp3'});

      final after = model.boardWidgets.single.config as SoundPadConfig;
      expect(after.emoji, '👏');
      expect(after.volume, 0.5);
      expect(after.triggerSeed, 3, reason: 'a refresh must not read as a trigger on a mirror');
    });
  });
}
