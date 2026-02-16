import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:intellihome_application/screens/devices/select_bonded_device_page.dart';
import 'package:intellihome_application/services/auth_service.dart';
import 'package:intellihome_application/services/sensor_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fl_chart/fl_chart.dart';
import 'profile_page.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final SensorService _sensorService = SensorService();
  
  String userName = "User";

  BluetoothConnection? connection;
  bool isConnected = false;
  String _buffer = '';

  double temp = 0.0;
  double humidity = 0.0;
  double dist = 0.0;
  bool isRaining = false;
  
  bool isPersonHome = true;
  bool isAlarm = false;
  bool isAcOn = false;

  List<FlSpot> tempHistory = [];
  List<FlSpot> humHistory = [];
  bool isLoadingCharts = false;

  Timer? _uploadTimer;
  bool isSyncing = false;
  List<Map<String, dynamic>> _syncBuffer = [];
  Timer? _syncTimeoutTimer;
  
  int _selectedIndex = 0;
  late AnimationController _alertController;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _requestPermissions();
    _runCleanup();
    _startUploadTimer();
    
    _alertController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  void _runCleanup() async {
    if (_auth.currentUserId != null) {
      await _sensorService.cleanupOldData(_auth.currentUserId!);
    }
  }

  void _startUploadTimer() {
    _uploadTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (isConnected && _auth.currentUserId != null) {
        _sensorService.uploadReading(_auth.currentUserId!, temp, humidity);
      }
    });
  }

  void _triggerSync() {
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bluetooth not connected!")));
      return;
    }

    setState(() {
      isSyncing = true;
      _syncBuffer.clear();
    });

    _sendCommand('9'); 
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing data from device...")));
  }

  void _finalizeSync() async {
    if (_syncBuffer.isNotEmpty && _auth.currentUserId != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Uploading ${_syncBuffer.length} synced records...")));
      
      await _sensorService.batchUploadReadings(_auth.currentUserId!, List.from(_syncBuffer));
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sync Complete!")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data received to sync.")));
    }

    setState(() {
      isSyncing = false;
      _syncBuffer.clear();
    });
  }

  void _fetchChartData() async {
    if (_auth.currentUserId == null) return;
    setState(() => isLoadingCharts = true);
    Map<String, List<FlSpot>> data = await _sensorService.fetch24hData(_auth.currentUserId!);
    if (mounted) {
      setState(() {
        tempHistory = data['temp']!;
        humHistory = data['humidity']!;
        isLoadingCharts = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 1) _fetchChartData();
  }

  Future<void> _loadUserName() async {
    try {
      Map<String, dynamic> userDetails = await _auth.getUserDetails();
      setState(() {
        userName = userDetails['name'] ?? "User";
      });
    } catch (e) {
      print("Error fetching name: $e");
    }
  }

  @override
  void dispose() {
    _alertController.dispose();
    connection?.dispose();
    _uploadTimer?.cancel();
    _syncTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.bluetooth, Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
  }

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
    if (values.length >= 8) {
      double t = double.tryParse(values[0]) ?? 0.0;
      double h = double.tryParse(values[1]) ?? 0.0;
      
      // Update UI state
      setState(() {
        temp = t;
        humidity = h;
        isRaining = values[3].trim() == '1';
        dist = double.tryParse(values[4]) ?? 0.0;
        isPersonHome = values[5].trim() == '1';
        isAlarm = values[6].trim() == '1';
        isAcOn = values[7].trim() == '1';
      });

      if (isSyncing) {
        _syncBuffer.add({'temp': t, 'humidity': h});
        
        _syncTimeoutTimer?.cancel();
        _syncTimeoutTimer = Timer(const Duration(seconds: 2), _finalizeSync);
      }
    }
  }

  void _sendCommand(String cmd) async {
    if (connection != null && isConnected) {
      connection!.output.add(ascii.encode(cmd));
      await connection!.output.allSent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("IntelliHome", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (isConnected)
            IconButton(
              icon: isSyncing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 2)) 
                : const Icon(Icons.sync, color: Colors.blue),
              tooltip: "Sync stored data",
              onPressed: isSyncing ? null : _triggerSync,
            ),
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
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome back,", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            Text("$userName", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2A2D3E))),
          ],
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            Expanded(child: _buildSensorCard("Temp", "${temp.toStringAsFixed(1)}°C", Icons.thermostat, Colors.orange)),
            const SizedBox(width: 15),
            Expanded(child: _buildSensorCard("Humidity", "${humidity.toStringAsFixed(1)}%", Icons.water_drop, Colors.blue)),
          ],
        ),
        const SizedBox(height: 20),
        _buildSecurityStatusCard(),
        const SizedBox(height: 20),
        if (isRaining) ...[
          _buildAlertBanner("RAINING DETECTED - WINDOWS LOCKED", Colors.blue),
          const SizedBox(height: 20),
        ],
        const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true, 
          physics: const NeverScrollableScrollPhysics(), 
          crossAxisCount: 2, 
          crossAxisSpacing: 15, 
          mainAxisSpacing: 15, 
          childAspectRatio: 1.5, 
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

  Widget _buildAnalytics() {
    if (isLoadingCharts) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (tempHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text("No data available yet.", style: TextStyle(color: Colors.grey)),
            Text("Wait for 5-min cycle or use Sync.", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text("Temperature History (24h)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                minY: 20, maxY: 40,
                lineBarsData: [LineChartBarData(spots: tempHistory, isCurved: true, color: Colors.orange, dotData: const FlDotData(show: true))],
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
              ),
            ),
          ),
          const Divider(height: 40),
          const Text("Humidity History (24h)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                minY: 0, maxY: 100,
                lineBarsData: [LineChartBarData(spots: humHistory, isCurved: true, color: Colors.blue, dotData: const FlDotData(show: true))],
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStatusCard() {
    Color bgColor;
    Color iconColor;
    IconData icon;
    String statusText;
    String subText;

    if (isAlarm) {
      bgColor = Colors.red.shade100;
      iconColor = Colors.red;
      icon = Icons.warning_amber_rounded;
      statusText = "INTRUDER ALERT!";
      subText = "Motion Detected while Armed";
    } else if (isPersonHome) {
      bgColor = Colors.green.shade100;
      iconColor = Colors.green.shade700;
      icon = Icons.home_filled;
      statusText = "HOME - SAFE";
      subText = "Monitoring Inactive";
    } else {
      bgColor = Colors.orange.shade100;
      iconColor = Colors.orange.shade800;
      icon = Icons.lock_outline;
      statusText = "AWAY - ARMED";
      subText = "Monitoring Active";
    }

    return AnimatedBuilder(
      animation: _alertController,
      builder: (context, child) {
        double scale = isAlarm ? 1.0 + (_alertController.value * 0.05) : 1.0;
        
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: isAlarm ? Border.all(color: Colors.red, width: 2) : null,
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: iconColor),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText, 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: iconColor)
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$subText • Dist: ${dist.toStringAsFixed(1)} cm",
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 10),
          Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String title, String subtitle, IconData icon, Color color, String cmd) {
    return GestureDetector(
      onTap: () => _sendCommand(cmd),
      child: Container(
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