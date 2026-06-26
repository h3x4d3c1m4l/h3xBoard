import 'package:fluent_ui/fluent_ui.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:h3xboard/models/converters/color_converter.dart';

part 'board.freezed.dart';
part 'board.g.dart';

enum BoardLinePattern { none, horizontal, grid }

@freezed
abstract class Board with _$Board {

  const Board._();

  const factory Board({
    required String id,
    required String title,
    @ColorConverter() required Color backgroundColor,
    required bool isChalkboard,
    required BoardLinePattern linePattern,
    required double lineSpacing,
    @ColorConverter() required Color lineColor,
    // The id of an uploaded file (see `H3xBoardFileService`) used as the board
    // background image, drawn over [backgroundColor]. null = no background image.
    String? backgroundFileId,
  }) = _Board;

  factory Board.fromJson(Map<String, dynamic> json) => _$BoardFromJson(json);

}
