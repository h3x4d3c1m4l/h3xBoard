import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

class FullscreenService {

  StreamController<bool>? _controller;
  web.EventListener? _listener;

  bool get isSupported => kIsWeb && web.document.fullscreenEnabled;

  bool get isFullscreen => kIsWeb && web.document.fullscreenElement != null;

  Stream<bool> get onChange {
    _controller ??= StreamController<bool>.broadcast(
      onListen: _attachListener,
      onCancel: _detachListener,
    );
    return _controller!.stream;
  }

  Future<void> requestFullscreen() async {
    if (!kIsWeb) return;
    await web.document.documentElement?.requestFullscreen().toDart;
  }

  Future<void> exitFullscreen() async {
    if (!kIsWeb) return;
    await web.document.exitFullscreen().toDart;
  }

  void _attachListener() {
    _listener = ((web.Event _) {
      _controller?.add(isFullscreen);
    }).toJS;
    web.document.addEventListener('fullscreenchange', _listener);
  }

  void _detachListener() {
    if (_listener != null) {
      web.document.removeEventListener('fullscreenchange', _listener);
      _listener = null;
    }
  }

  void dispose() {
    _detachListener();
    _controller?.close();
    _controller = null;
  }

}
