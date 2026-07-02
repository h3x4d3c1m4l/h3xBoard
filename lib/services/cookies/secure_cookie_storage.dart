import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A cookie_jar [Storage] backed by [FlutterSecureStorage].
class SecureCookieStorage implements Storage {

  static const _prefix = 'h3xboard_cookie_';

  final FlutterSecureStorage _secureStorage;

  SecureCookieStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) => _secureStorage.read(key: _prefix + key);

  @override
  Future<void> write(String key, String value) => _secureStorage.write(key: _prefix + key, value: value);

  @override
  Future<void> delete(String key) => _secureStorage.delete(key: _prefix + key);

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await _secureStorage.delete(key: _prefix + key);
    }
  }

}
