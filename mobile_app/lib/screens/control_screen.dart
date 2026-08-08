import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mqtt_service.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({Key? key}) : super(key: key);

  Widget build(BuildContext context) {
    final mqttService = Provider.of<MQTTService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontrol Pompa'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: mqttService.isPumpOn
                      ? Colors.green.shade100
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.water_drop,
                  size: 80,
                  color: mqttService.isPumpOn ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                mqttService.isPumpOn ? 'POMPA MENYALA' : 'POMPA MATI',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: mqttService.isPumpOn ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    mqttService.controlPump(!mqttService.isPumpOn);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        mqttService.isPumpOn ? Colors.red : Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    mqttService.isPumpOn ? 'MATIKAN POMPA' : 'NYALAKAN POMPA',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
