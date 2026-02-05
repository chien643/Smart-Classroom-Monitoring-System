import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  // ================= SINGLETON =================
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  // ================= CONFIG =================
  static const String broker = '10.141.142.204';
  static const int port = 1883;
  static const String username = 'chienhn1604';
  static const String password = 'jayanhoo2004';
  static const String clientId = 'flutter_classroom_app';

  late MqttServerClient _client;
  bool _connected = false;

  // ================= CALLBACK CHO UI =================
  /// ControlPage gán callback này
  void Function(String topic, String payload)? onMessage;

  // ================= SENSOR DATA =================
  double temperature = 0;
  double humidity = 0;
  double light = 0;

  /// notifier để UI rebuild sensor card
  final ValueNotifier<int> sensorTick = ValueNotifier(0);

  // ================= CONNECT =================
  Future<void> connect() async {
    if (_connected) return;

    _client = MqttServerClient(broker, clientId);
    _client.port = port;
    _client.keepAlivePeriod = 20;
    _client.autoReconnect = true;
    _client.logging(on: false);

    _client.connectionMessage = MqttConnectMessage()
        .authenticateAs(username, password)
        .withClientIdentifier(clientId)
        .startClean()
        .keepAliveFor(20)
        .withWillQos(MqttQos.atLeastOnce);

    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onSubscribed = (t) => debugPrint('[MQTT] Subscribed $t');

    try {
      debugPrint('[MQTT] Connecting...');
      await _client.connect();
    } catch (e) {
      debugPrint('[MQTT] Connect error: $e');
      _client.disconnect();
    }
  }

  // ================= EVENTS =================
  void _onConnected() {
    debugPrint('[MQTT] Connected');
    _connected = true;

    // 🔥 SUBSCRIBE 1 LẦN DUY NHẤT
    _client.subscribe('home/classroom/#', MqttQos.atMostOnce);

    // 🔥 LISTEN MESSAGE
    _client.updates!.listen(_onMessageInternal);
  }

  void _onDisconnected() {
    debugPrint('[MQTT] Disconnected');
    _connected = false;
  }

  // ================= MESSAGE HANDLER =================
  void _onMessageInternal(List<MqttReceivedMessage<MqttMessage>> events) {
    final recMess = events.first.payload as MqttPublishMessage;
    final payload =
        MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    final topic = events.first.topic;

    debugPrint('[MQTT] $topic → $payload');

    // ===== SENSOR =====
    if (topic == 'home/classroom/temperature') {
      temperature = double.tryParse(payload) ?? temperature;
      sensorTick.value++;
    } else if (topic == 'home/classroom/humidity') {
      humidity = double.tryParse(payload) ?? humidity;
      sensorTick.value++;
    } else if (topic == 'home/classroom/light') {
      light = double.tryParse(payload) ?? light;
      sensorTick.value++;
    }

    // ===== GỬI LÊN UI (relay/state, auto/state) =====
    if (onMessage != null) {
      onMessage!(topic, payload);
    }
  }

  // ================= PUBLISH =================
  void publish(String topic, String message) {
    if (!_connected) {
      debugPrint('[MQTT] Publish ignored (not connected)');
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    _client.publishMessage(
      topic,
      MqttQos.atMostOnce,
      builder.payload!,
    );
  }

  // ================= DISCONNECT =================
  void disconnect() {
    if (_connected) {
      _client.disconnect();
      _connected = false;
    }
  }
}
