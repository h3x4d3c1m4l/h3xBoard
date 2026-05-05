import 'package:fluent_ui/fluent_ui.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'board.freezed.dart';

enum BoardLinePattern { none, horizontal, grid }

@freezed
abstract class Board with _$Board {

  const Board._();

  const factory Board({
    required String title,
    required Color backgroundColor,
    required bool isChalkboard,
    required BoardLinePattern linePattern,
    required double lineSpacing,
    required Color lineColor,
  }) = _Board;

}
