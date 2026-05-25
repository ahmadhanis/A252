import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 MQTT Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const MqttDhtServoScreen(),
    );
  }
}

class MqttDhtServoScreen extends StatefulWidget {
  const MqttDhtServoScreen({super.key});

  @override
  State<MqttDhtServoScreen> createState() => _MqttDhtServoScreenState();
}

class _MqttDhtServoScreenState extends State<MqttDhtServoScreen> {
  final String mqttServer = '10.19.28.53';
  final int mqttPort = 1883;

  late MqttServerClient client;

  final String temperatureTopic = 'esp32/dht11/temperature';
  final String humidityTopic = 'esp32/dht11/humidity';
  final String espStatusTopic = 'esp32/status';
  final String servoControlTopic = 'esp32/servo/control';
  final String servoStatusTopic = 'esp32/servo/status';

  String temperature = '--';
  String humidity = '--';
  String espStatus = 'Waiting for ESP32 data...';
  String servoStatus = 'Servo not updated';
  String mqttStatus = 'Disconnected';

  bool isConnected = false;
  double servoAngle = 0;

  @override
  void initState() {
    super.initState();
    connectToMqtt();
  }

  Future<void> connectToMqtt() async {
    final String clientId =
        'flutter_android_client_${DateTime.now().millisecondsSinceEpoch}';

    client = MqttServerClient(mqttServer, clientId);

    client.port = mqttPort;
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.secure = false;

    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onSubscribed = onSubscribed;

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    setState(() {
      mqttStatus = 'Connecting to MQTT broker...';
    });

    try {
      await client.connect();
    } catch (e) {
      setState(() {
        mqttStatus = 'Connection failed: $e';
        isConnected = false;
      });

      client.disconnect();
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      setState(() {
        mqttStatus = 'Connected to MQTT broker';
        isConnected = true;
      });

      subscribeToTopics();
      listenToMessages();
    } else {
      setState(() {
        mqttStatus = 'Connection failed';
        isConnected = false;
      });

      client.disconnect();
    }
  }

  void subscribeToTopics() {
    client.subscribe(temperatureTopic, MqttQos.atMostOnce);
    client.subscribe(humidityTopic, MqttQos.atMostOnce);
    client.subscribe(espStatusTopic, MqttQos.atMostOnce);
    client.subscribe(servoStatusTopic, MqttQos.atMostOnce);
  }

  void listenToMessages() {
    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final MqttPublishMessage message =
          messages[0].payload as MqttPublishMessage;

      final String topic = messages[0].topic;

      final String payload = MqttPublishPayload.bytesToStringAsString(
        message.payload.message,
      );

      setState(() {
        if (topic == temperatureTopic) {
          temperature = payload;
        } else if (topic == humidityTopic) {
          humidity = payload;
        } else if (topic == espStatusTopic) {
          espStatus = payload;
        } else if (topic == servoStatusTopic) {
          servoStatus = payload;
        }
      });

      debugPrint('Topic: $topic');
      debugPrint('Payload: $payload');
    });
  }

  void publishServoCommand(String command) {
    if (!isConnected) {
      setState(() {
        servoStatus = 'MQTT is not connected';
      });
      return;
    }

    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(command);

    client.publishMessage(
      servoControlTopic,
      MqttQos.atMostOnce,
      builder.payload!,
    );

    setState(() {
      servoStatus = 'Command sent: $command';
    });

    debugPrint('Servo command sent: $command');
  }

  void onConnected() {
    debugPrint('MQTT connected');
  }

  void onDisconnected() {
    debugPrint('MQTT disconnected');

    if (mounted) {
      setState(() {
        mqttStatus = 'Disconnected';
        isConnected = false;
      });
    }
  }

  void onSubscribed(String topic) {
    debugPrint('Subscribed to $topic');
  }

  Future<void> reconnectMqtt() async {
    if (isConnected) {
      client.disconnect();
    }

    await connectToMqtt();
  }

  @override
  void dispose() {
    if (isConnected) {
      client.disconnect();
    }

    super.dispose();
  }

  Widget buildStatusCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: isConnected ? Colors.green : Colors.red,
                  size: 36,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    mqttStatus,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              children: [
                const Icon(Icons.memory, size: 32, color: Colors.orange),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    espStatus,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSensorCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 42, color: Colors.blue),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$value $unit',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildServoControlCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.settings_remote, size: 36, color: Colors.purple),
                SizedBox(width: 16),
                Text(
                  'Servo Control',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              'Servo Angle: ${servoAngle.round()}°',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            Slider(
              value: servoAngle,
              min: 0,
              max: 180,
              divisions: 180,
              label: '${servoAngle.round()}°',
              onChanged: (value) {
                setState(() {
                  servoAngle = value;
                });
              },
              onChangeEnd: (value) {
                publishServoCommand(value.round().toString());
              },
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        servoAngle = 90;
                      });
                      publishServoCommand('OPEN');
                    },
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Open'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        servoAngle = 0;
                      });
                      publishServoCommand('CLOSE');
                    },
                    icon: const Icon(Icons.lock),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              servoStatus,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTopicInfoCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'MQTT Broker: $mqttServer:$mqttPort\n'
          'Temperature Topic: $temperatureTopic\n'
          'Humidity Topic: $humidityTopic\n'
          'Servo Control Topic: $servoControlTopic\n'
          'Servo Status Topic: $servoStatusTopic',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f7fb),
      appBar: AppBar(
        title: const Text('ESP32 DHT11 + Servo MQTT'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: reconnectMqtt,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            buildStatusCard(),

            const SizedBox(height: 16),

            buildSensorCard(
              title: 'Temperature',
              value: temperature,
              unit: '°C',
              icon: Icons.thermostat,
            ),

            const SizedBox(height: 16),

            buildSensorCard(
              title: 'Humidity',
              value: humidity,
              unit: '%',
              icon: Icons.water_drop,
            ),

            const SizedBox(height: 16),

            buildServoControlCard(),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: reconnectMqtt,
              icon: const Icon(Icons.refresh),
              label: const Text('Reconnect MQTT'),
            ),

            const SizedBox(height: 16),

            buildTopicInfoCard(),
          ],
        ),
      ),
    );
  }
}