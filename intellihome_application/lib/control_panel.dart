import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class ControlPanelPage extends StatefulWidget {
  const ControlPanelPage({super.key});

  @override
  State<ControlPanelPage> createState() => _ControlPanelPageState();
}

class _ControlPanelPageState extends State<ControlPanelPage> {
  // Bluetooth Variables
  BluetoothConnection? connection;
  bool isConnected = false;
  String _buffer = ''; // Stores incoming partial data

  // Sensor Data Variables
  String temp = "--";
  String light = "--";
  String rain = "--";
  bool isRaining = false;
  bool isWindowOpen = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // 1. Request Android Permissions
  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  // 2. Connect to the HC-05/06 Module
  Future<void> _connectToBluetooth() async {
    // GET LIST OF PAIRED DEVICES
    List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    
    // FIND YOUR DEVICE (Change "HC-05" to your module's actual name!)
    BluetoothDevice? device;
    try {
      device = devices.firstWhere((d) => d.name == "HC-05"); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("HC-05 not found in paired devices!")),
      );
      return;
    }

    // ESTABLISH CONNECTION
    try {
      connection = await BluetoothConnection.toAddress(device.address);
      setState(() {
        isConnected = true;
      });
      
      // START LISTENING TO DATA STREAM
      connection!.input!.listen(_onDataReceived).onDone(() {
        setState(() { isConnected = false; });
      });
      
    } catch (e) {
      print("Connection Error: $e");
    }
  }

  // 3. Process Incoming Data (The Parser)
  void _onDataReceived(Uint8List data) {
    // Decode bytes to string and append to buffer
    String incoming = ascii.decode(data);
    _buffer += incoming;

    // If we see a "New Line" (\n), we have a full message
    if (_buffer.contains('\n')) {
      List<String> lines = _buffer.split('\n');
      
      // Process the last complete line (most recent data)
      // We iterate to handle cases where multiple lines arrive at once
      for (String line in lines) {
        if (line.isNotEmpty && line.contains(',')) {
          _parseSensorData(line);
        }
      }
      
      // Keep only the incomplete part for the next chunk
      _buffer = lines.last; 
    }
  }

  void _parseSensorData(String line) {
    // Expected format: "28.5,0.80,0.10,0" (Temp, Light, Rain, IsRaining)
    List<String> values = line.split(',');

    if (values.length >= 4) {
      setState(() {
        temp = values[0];
        light = values[1];
        rain = values[2];
        isRaining = values[3].trim() == '1';
        
        // Safety: If it's raining, force UI to show window closed
        if (isRaining) isWindowOpen = false;
      });
    }
  }

  // 4. Send Commands to STM32
  void _sendCommand(String cmd) async {
    if (connection != null && isConnected) {
      connection!.output.add(ascii.encode(cmd));
      await connection!.output.allSent;
      
      // Optimistic UI update
      if (cmd == '3' && !isRaining) setState(() => isWindowOpen = true);
      if (cmd == '4') setState(() => isWindowOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smart Home Controller")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // CONNECTION STATUS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isConnected ? "Connected to Home" : "Disconnected",
                    style: TextStyle(color: isConnected ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: isConnected ? () => connection?.close() : _connectToBluetooth,
                  child: Text(isConnected ? "Disconnect" : "Connect"),
                ),
              ],
            ),
            const Divider(height: 30),

            // SENSOR DASHBOARD
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSensorCard("Temp", "$temp°C", Icons.thermostat),
                _buildSensorCard("Light", light, Icons.light_mode),
                _buildSensorCard("Rain", rain, Icons.water_drop, isAlert: isRaining),
              ],
            ),
            const SizedBox(height: 20),
            
            if (isRaining)
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.redAccent,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 10),
                    Text("RAINING! WINDOW BLOCKED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            const Divider(height: 30),
            
            // CONTROLS
            const Text("Manual Controls", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton("AC ON", '1', Colors.blue),
                _buildControlButton("AC AUTO", '2', Colors.grey),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Window Open (Disabled if raining)
                Opacity(
                  opacity: isRaining ? 0.5 : 1.0,
                  child: _buildControlButton("Win OPEN", '3', Colors.orange, disabled: isRaining),
                ),
                _buildControlButton("Win CLOSE", '4', Colors.orange),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton("Curtain UP", '5', Colors.purple),
                _buildControlButton("Curtain DOWN", '6', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard(String title, String value, IconData icon, {bool isAlert = false}) {
    return Card(
      color: isAlert ? Colors.red.shade100 : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 30, color: isAlert ? Colors.red : Colors.blue),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(String label, String command, Color color, {bool disabled = false}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: disabled ? null : () => _sendCommand(command),
      child: Text(label),
    );
  }
}