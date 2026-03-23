import 'package:mqtt_client/mqtt_client.dart';

Future<MqttClient> connectMqttImpl({
  required String host,
  required int port,
  required String username,
  required String password,
  required bool useTls,
  required String websocketPath,
  required void Function() onConnected,
  required void Function() onDisconnected,
}) {
  throw UnsupportedError('MQTT is not supported on this platform.');
}
