import 'package:mqtt_client/mqtt_client.dart';

import 'mqtt_connector_stub.dart'
    if (dart.library.js_interop) 'mqtt_connector_web.dart'
    if (dart.library.io) 'mqtt_connector_io.dart';

Future<MqttClient> connectPlatformMqtt({
  required String host,
  required int port,
  required String username,
  required String password,
  required bool useTls,
  required String websocketPath,
  required void Function() onConnected,
  required void Function() onDisconnected,
}) {
  return connectMqttImpl(
    host: host,
    port: port,
    username: username,
    password: password,
    useTls: useTls,
    websocketPath: websocketPath,
    onConnected: onConnected,
    onDisconnected: onDisconnected,
  );
}
