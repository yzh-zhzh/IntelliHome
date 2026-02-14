// ignore_for_file: unused_import

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class SelectBondedDevicePage extends StatefulWidget {
  final bool checkAvailability;

  const SelectBondedDevicePage({super.key, this.checkAvailability = true});

  @override
  State<SelectBondedDevicePage> createState() => _SelectBondedDevicePageState();
}

class _SelectBondedDevicePageState extends State<SelectBondedDevicePage> {
  List<BluetoothDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() {
    FlutterBluetoothSerial.instance.getBondedDevices().then((List<BluetoothDevice> bondedDevices) {
      setState(() {
        _devices = bondedDevices;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Device'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Select your Smart Home Module",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                BluetoothDevice device = _devices[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth, color: Color(0xFF6C63FF)),
                      title: Text(device.name ?? "Unknown Device", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(device.address),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).pop(device);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}