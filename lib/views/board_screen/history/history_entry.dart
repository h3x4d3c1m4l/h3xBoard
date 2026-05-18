class HistoryEntry {

  final void Function() undo;
  final void Function() redo;

  const HistoryEntry({required this.undo, required this.redo});

}
