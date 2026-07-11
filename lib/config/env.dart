import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', requireEnvFile: false)
abstract class Env {

  @EnviedField(varName: 'API_URL', defaultValue: 'http://localhost:8081')
  static const String apiUrl = _Env.apiUrl;

}
