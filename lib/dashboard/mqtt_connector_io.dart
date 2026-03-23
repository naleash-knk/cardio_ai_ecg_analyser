import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

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
  final String clientId = 'aegis_mobile_${DateTime.now().millisecondsSinceEpoch}';
  final MqttServerClient client = MqttServerClient.withPort(host, clientId, port);
  client.secure = useTls;
  client.keepAlivePeriod = 20;
  client.setProtocolV311();
  client.onDisconnected = onDisconnected;
  client.onConnected = onConnected;
  client.logging(on: false);

  client.connectionMessage = MqttConnectMessage()
      .withClientIdentifier(clientId)
      .startClean()
      .withWillQos(MqttQos.atMostOnce);

  await client.connect(
    username.isNotEmpty ? username : null,
    password.isNotEmpty ? password : null,
  );
  if (client.connectionStatus?.state != MqttConnectionState.connected) {
    throw Exception(client.connectionStatus?.returnCode);
  }

  return client;
}
