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
  // --- BLUETOOTH & DATA VARIABLES (Same as before) ---
  BluetoothConnection? connection;
  bool isConnected = false;
  String _buffer = '';
  
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

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> _connectToBluetooth() async {
    // Show loading indicator
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    BluetoothDevice? device;
    try {
      device = devices.firstWhere((d) => d.name == "HC-05"); // Check your device name!
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("HC-05 not found! Pair it in settings first.")),
      );
      return;
    }

    try {
      connection = await BluetoothConnection.toAddress(device.address);
      setState(() => isConnected = true);
      
      connection!.input!.listen(_onDataReceived).onDone(() {
        setState(() => isConnected = false);
      });
      Navigator.pop(context); // Close loading
    } catch (e) {
      Navigator.pop(context);
      print("Connection Error: $e");
    }
  }

  void _onDataReceived(Uint8List data) {
    String incoming = ascii.decode(data);
    _buffer += incoming;
    if (_buffer.contains('\n')) {
      List<String> lines = _buffer.split('\n');
      for (String line in lines) {
        if (line.isNotEmpty && line.contains(',')) {
          _parseSensorData(line);
        }
      }
      _buffer = lines.last; 
    }
  }

  void _parseSensorData(String line) {
    List<String> values = line.split(',');
    if (values.length >= 4) {
      setState(() {
        temp = values[0];
        light = values[1];
        rain = values[2];
        isRaining = values[3].trim() == '1';
        if (isRaining) isWindowOpen = false;
      });
    }
  }

  void _sendCommand(String cmd) async {
    if (connection != null && isConnected) {
      connection!.output.add(ascii.encode(cmd));
      await connection!.output.allSent;
      
      if (cmd == '3' && !isRaining) setState(() => isWindowOpen = true);
      if (cmd == '4') setState(() => isWindowOpen = false);
    }
  }

  // --- NEW UI DESIGN STARTS HERE ---

  @override
  Widget build(BuildContext context) {
    // Define a modern color palette
    final bgColor = Colors.grey.shade100;
    final primaryColor = const Color(0xFF2A2D3E); // Dark Navy
    final accentColor = const Color(0xFF6C63FF); // Modern Blurple

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER & CONNECTION STATUS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Welcome Home,", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      Text("Smart Control", style: TextStyle(color: primaryColor, fontSize: 26, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  InkWell(
                    onTap: isConnected ? () => connection?.close() : _connectToBluetooth,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isConnected ? Colors.green : Colors.red),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 10, color: isConnected ? Colors.green : Colors.red),
                          const SizedBox(width: 8),
                          Text(isConnected ? "Online" : "Connect", 
                               style: TextStyle(color: isConnected ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),

              // 2. SENSOR CARDS (WIDGETS)
              Row(
                children: [
                  Expanded(child: _buildSensorTile("Temp", "$temp°C", Icons.thermostat, Colors.orange)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildSensorTile("Light", light, Icons.wb_sunny, Colors.amber)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildSensorTile("Rain", rain, Icons.water_drop, Colors.blue, isAlert: isRaining)),
                ],
              ),

              const SizedBox(height: 20),

              // 3. RAIN ALERT BANNER
              if (isRaining)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Text("RAINING! WINDOW AUTO-LOCKED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

              const SizedBox(height: 30),
              
              Text("Quick Actions", style: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              // 4. CONTROL GRID
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5, // Make buttons wider than they are tall
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  children: [
                    _buildActionBtn("AC ON", "Manual Mode", Icons.ac_unit, Colors.blue, '1'),
                    _buildActionBtn("AC AUTO", "Sensor Mode", Icons.hdr_auto, Colors.teal, '2'),
                    _buildActionBtn("Win OPEN", "Open Window", Icons.window, Colors.orange, '3', isLocked: isRaining),
                    _buildActionBtn("Win CLOSE", "Close Window", Icons.sensor_window, Colors.deepOrange, '4'),
                    _buildActionBtn("Curtain UP", "Open Blinds", Icons.vertical_align_top, Colors.purple, '5'),
                    _buildActionBtn("Curtain DOWN", "Close Blinds", Icons.vertical_align_bottom, Colors.deepPurple, '6'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSensorTile(String label, String value, IconData icon, Color color, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        border: isAlert ? Border.all(color: Colors.red.shade200) : null,
      ),
      child: Column(
        children: [
          Icon(icon, color: isAlert ? Colors.red : color, size: 28),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String title, String subtitle, IconData icon, Color color, String cmd, {bool isLocked = false}) {
    return InkWell(
      onTap: isLocked ? null : () => _sendCommand(cmd),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isLocked ? Colors.grey.shade200 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isLocked ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(isLocked ? Icons.lock : icon, color: isLocked ? Colors.grey : color, size: 24),
                if (isLocked) const Icon(Icons.block, color: Colors.red, size: 16),
              ],
            ),
            const Spacer(),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isLocked ? Colors.grey : Colors.grey.shade800)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: isLocked ? Colors.grey : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}