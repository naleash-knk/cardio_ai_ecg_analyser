import 'package:mqtt_client/mqtt_browser_client.dart';
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
}) async {
  final String protocol = useTls ? 'wss' : 'ws';
  final String serverUrl = '$protocol://$host:$port$websocketPath';
  final String clientId = 'aegis_web_${DateTime.now().millisecondsSinceEpoch}';
  final MqttBrowserClient client = MqttBrowserClient(serverUrl, clientId);

  client.keepAlivePeriod = 20;
  client.setProtocolV311();
  client.onDisconnected = onDisconnected;
  client.onConnected = onConnected;
  client.logging(on: false);

  final MqttConnectMessage connectMessage = MqttConnectMessage()
      .withClientIdentifier(clientId)
      .startClean()
      .withWillQos(MqttQos.atMostOnce);
  client.connectionMessage = connectMessage;

  await client.connect(
    username.isNotEmpty ? username : null,
    password.isNotEmpty ? password : null,
  );
  if (client.connectionStatus?.state != MqttConnectionState.connected) {
    throw Exception(client.connectionStatus?.returnCode);
  }

  return client;
}
