import 'package:h3xboard/views/board_screen/history/history_entry.dart';
import 'package:mobx/mobx.dart';

part 'history_manager.g.dart';

class HistoryManager = HistoryManagerBase with _$HistoryManager;

abstract class HistoryManagerBase with Store {

  static const int _maxEntries = 100;

  final _undoStack = <HistoryEntry>[];
  final _redoStack = <HistoryEntry>[];

  /// Fired whenever the board state changes through a step (push/undo/redo).
  /// Used to trigger autosave at the same granularity as undo steps.
  void Function()? onChange;

  @readonly
  bool _canUndo = false;

  @readonly
  bool _canRedo = false;

  @action
  void push(HistoryEntry entry) {
    _undoStack.add(entry);
    if (_undoStack.length > _maxEntries) _undoStack.removeAt(0);
    _redoStack.clear();
    _canUndo = true;
    _canRedo = false;
    onChange?.call();
  }

  @action
  void undo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    entry.undo();
    _redoStack.add(entry);
    _canUndo = _undoStack.isNotEmpty;
    _canRedo = true;
    onChange?.call();
  }

  @action
  void redo() {
    if (_redoStack.isEmpty) return;
    final entry = _redoStack.removeLast();
    entry.redo();
    _undoStack.add(entry);
    _canUndo = true;
    _canRedo = _redoStack.isNotEmpty;
    onChange?.call();
  }

}
