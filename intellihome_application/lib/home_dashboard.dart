import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'select_bonded_device_page.dart'; 

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  // --- BLUETOOTH & DATA ---
  BluetoothConnection? connection;
  bool isConnected = false;
  String _buffer = '';

  // Sensor Data
  double temp = 0.0;
  double humidity = 0.0;
  double dist = 0.0;
  bool isRaining = false;
  
  // Status Flags (New!)
  bool isPersonHome = true;
  bool isAlarm = false;
  bool isAcOn = false;

  // History Data for Charts (Last 20 points)
  List<FlSpot> tempHistory = [];
  List<FlSpot> humHistory = [];
  int timeCounter = 0;

  int _selectedIndex = 0; // Tab Index

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.bluetooth, Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
  }

  // --- BLUETOOTH LOGIC ---
  Future<void> _connectToBluetooth() async {
    final BluetoothDevice? selectedDevice = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SelectBondedDevicePage(checkAvailability: false)),
    );

    if (selectedDevice == null) return;

    try {
      connection = await BluetoothConnection.toAddress(selectedDevice.address);
      setState(() => isConnected = true);
      connection!.input!.listen(_onDataReceived).onDone(() {
        if (mounted) setState(() => isConnected = false);
      });
    } catch (e) {
      print("Connection Error: $e");
    }
  }

  void _onDataReceived(Uint8List data) {
    String incoming = ascii.decode(data);
    _buffer += incoming;
    
    if (_buffer.contains('\n')) {
      List<String> lines = _buffer.split('\n');
      for (String line in lines) {
        String trimmedLine = line.trim(); 
        if (trimmedLine.isNotEmpty && trimmedLine.contains(',')) {
          _parseData(trimmedLine);
        }
      }
      _buffer = lines.last; 
    }
  }

  void _parseData(String line) {
    List<String> values = line.split(',');
    // Expected: Temp, Hum, RainVal, IsRaining, Dist, IsHome, IsAlarm, IsAC
    if (values.length >= 8) {
      setState(() {
        temp = double.tryParse(values[0]) ?? 0.0;
        humidity = double.tryParse(values[1]) ?? 0.0;
        // Skip RainVal (index 2)
        isRaining = values[3].trim() == '1';
        dist = double.tryParse(values[4]) ?? 0.0;
        isPersonHome = values[5].trim() == '1';
        isAlarm = values[6].trim() == '1';
        isAcOn = values[7].trim() == '1';

        // Update Charts
        timeCounter++;
        tempHistory.add(FlSpot(timeCounter.toDouble(), temp));
        humHistory.add(FlSpot(timeCounter.toDouble(), humidity));
        
        // Keep only last 20 points
        if (tempHistory.length > 20) tempHistory.removeAt(0);
        if (humHistory.length > 20) humHistory.removeAt(0);
      });
    }
  }

  void _sendCommand(String cmd) async {
    if (connection != null && isConnected) {
      connection!.output.add(ascii.encode(cmd));
      await connection!.output.allSent;
    }
  }

  // --- UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("IntelliHome", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
            color: isConnected ? Colors.blue : Colors.grey,
            onPressed: isConnected ? () => connection?.close() : _connectToBluetooth,
          )
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(),
          _buildAnalytics(),
          _buildSecurityHub(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Controls'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.security), label: 'Security'),
        ],
      ),
    );
  }

  // --- TAB 1: DASHBOARD ---
  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // --- SENSOR CARDS ---
        Row(
          children: [
            Expanded(child: _buildSensorCard("Temp", "${temp.toStringAsFixed(1)}°C", Icons.thermostat, Colors.orange)),
            const SizedBox(width: 15),
            Expanded(child: _buildSensorCard("Humidity", "${humidity.toStringAsFixed(1)}%", Icons.water_drop, Colors.blue)),
          ],
        ),
        const SizedBox(height: 20),
        
        // --- ALERTS ---
        if (isRaining) ...[
          _buildAlertBanner("RAINING DETECTED", Colors.blue),
          const SizedBox(height: 20),
        ],
        if (isAlarm) ...[
          _buildAlertBanner("INTRUDER ALARM ACTIVE!", Colors.red),
          const SizedBox(height: 20),
        ],

        const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        
        // --- GRID VIEW (This fixes the alignment) ---
        GridView.count(
          shrinkWrap: true, // Allows Grid to sit inside ListView
          physics: const NeverScrollableScrollPhysics(), // Disables Grid's internal scroll
          crossAxisCount: 2, // 2 Columns
          crossAxisSpacing: 15, // Horizontal gap
          mainAxisSpacing: 15, // Vertical gap
          childAspectRatio: 1.5, // Ratio > 1 makes buttons wider (rectangular) vs square
          children: [
            _buildActionBtn("AC", isAcOn ? "ON" : "OFF", Icons.ac_unit, isAcOn ? Colors.blue : Colors.grey, '1'),
            _buildActionBtn("AC OFF", "AUTO AC Mode", Icons.power_off, Colors.red.shade300, '2'),
            _buildActionBtn("Window", "OPEN", Icons.window, Colors.green, '3'),
            _buildActionBtn("Window", "CLOSE", Icons.sensor_window, Colors.brown, '4'),
            _buildActionBtn("Curtain", "UP", Icons.vertical_align_top, Colors.purple, '5'),
            _buildActionBtn("Curtain", "DOWN", Icons.vertical_align_bottom, Colors.deepPurple, '6'),
          ],
        )
      ],
    );
  }

  // --- TAB 2: ANALYTICS (CHARTS) ---
  Widget _buildAnalytics() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text("Live Temperature", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 20, maxY: 40,
                lineBarsData: [LineChartBarData(spots: tempHistory, isCurved: true, color: Colors.orange, dotData: const FlDotData(show: false))],
                titlesData: const FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
              ),
            ),
          ),
          const Divider(height: 40),
          const Text("Live Humidity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0, maxY: 100,
                lineBarsData: [LineChartBarData(spots: humHistory, isCurved: true, color: Colors.blue, dotData: const FlDotData(show: false))],
                titlesData: const FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: SECURITY HUB ---
  Widget _buildSecurityHub() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isAlarm ? Icons.warning : (isPersonHome ? Icons.home : Icons.lock),
            size: 100,
            color: isAlarm ? Colors.red : (isPersonHome ? Colors.green : Colors.orange),
          ),
          const SizedBox(height: 20),
          Text(
            isAlarm ? "INTRUDER ALERT" : (isPersonHome ? "HOME MODE" : "AWAY MODE"),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isAlarm ? Colors.red : Colors.black),
          ),
          const SizedBox(height: 10),
          Text("Distance Sensor: ${dist.toStringAsFixed(1)} cm", style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 40),
          if (isAlarm)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
              onPressed: () {
                // To disarm remotely, you would need to implement a 'Disarm' command in C++
                // For now, we can just stop the AC or similar
              },
              icon: const Icon(Icons.notifications_off),
              label: const Text("SYSTEM TRIGGERED"),
            )
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---
  Widget _buildSensorCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner(String msg, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    );
  }

  Widget _buildActionBtn(String title, String subtitle, IconData icon, Color color, String cmd) {
    return GestureDetector(
      onTap: () => _sendCommand(cmd),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)]),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}