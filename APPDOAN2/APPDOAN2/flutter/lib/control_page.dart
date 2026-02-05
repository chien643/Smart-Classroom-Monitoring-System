import 'package:flutter/material.dart';
import '../mqtt_service.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  /// 🔥 Singleton – toàn app chỉ 1 MQTT
  final MqttService mqtt = MqttService();

  /// null = chưa nhận state từ ESP
  final Map<int, bool?> relayState = {
    1: null,
    2: null,
    3: null,
    4: null,
    5: null,
    6: null,
  };

  bool? autoEnabled;

  @override
  void initState() {
    super.initState();

    /// connect (nếu đã connect thì bỏ qua)
    mqtt.connect();

    /// 🔥 lắng nghe state từ ESP
    mqtt.onMessage = (topic, payload) {
      bool updated = false;

      // ===== RELAY STATE =====
      for (int i = 1; i <= 6; i++) {
        if (topic == 'home/classroom/relay$i/state') {
          relayState[i] = payload == 'ON';
          updated = true;
        }
      }

      // ===== AUTO STATE =====
      if (topic == 'home/classroom/auto/state') {
        autoEnabled = payload == 'ON';
        updated = true;
      }

      if (updated && mounted) {
        setState(() {});
      }
    };
  }

  // ================= ACTIONS =================
  /// CHỈ GỬI LỆNH – KHÔNG TỰ ĐỔI UI
  void toggleRelay(int i, bool value) {
    mqtt.publish(
      'home/classroom/relay$i/set',
      value ? 'ON' : 'OFF',
    );
  }

  void setAuto(bool value) {
    mqtt.publish(
      'home/classroom/auto/set',
      value ? 'ON' : 'OFF',
    );
  }

  // ================= UI =================
  Widget sensorCard() {
    return ValueListenableBuilder(
      valueListenable: mqtt.sensorTick,
      builder: (_, __, ___) {
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cảm biến',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(Icons.thermostat),
                    const SizedBox(width: 8),
                    Text(
                      'Nhiệt độ: ${mqtt.temperature.toStringAsFixed(1)} °C',
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    const Icon(Icons.water_drop),
                    const SizedBox(width: 8),
                    Text(
                      'Độ ẩm: ${mqtt.humidity.toStringAsFixed(1)} %',
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    const Icon(Icons.light_mode),
                    const SizedBox(width: 8),
                    Text(
                      'Ánh sáng: ${mqtt.light.toStringAsFixed(1)} lux',
                    ),
                  ],
                ),

                const Divider(height: 20),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('AUTO cảm biến'),
                  subtitle: Text(
                    autoEnabled == null
                        ? 'Đang đồng bộ...'
                        : (autoEnabled! ? 'AUTO: ON' : 'AUTO: OFF'),
                  ),
                  value: autoEnabled ?? false,
                  onChanged: autoEnabled == null ? null : setAuto,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget deviceCard(int i, String name, IconData icon) {
    final state = relayState[i];

    return Card(
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor:
              state == true ? Colors.blue : Colors.grey,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          state == null
              ? 'Đang đồng bộ...'
              : (state ? 'ĐANG BẬT' : 'ĐANG TẮT'),
        ),
        trailing: Switch(
          value: state ?? false,
          onChanged: state == null ? null : (v) => toggleRelay(i, v),
        ),
      ),
    );
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Điều khiển & Cảm biến'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          sensorCard(),
          const SizedBox(height: 12),

          deviceCard(1, 'Quạt 1', Icons.air),
          deviceCard(2, 'Quạt 2', Icons.air),
          deviceCard(3, 'Quạt 3', Icons.air),
          deviceCard(4, 'Đèn 1', Icons.lightbulb),
          deviceCard(5, 'Đèn 2', Icons.lightbulb),
          deviceCard(6, 'Đèn 3', Icons.lightbulb),
        ],
      ),
    );
  }
}
