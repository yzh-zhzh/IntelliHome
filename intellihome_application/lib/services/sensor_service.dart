import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class SensorService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Upload Data (Run this every 5 mins)
  Future<void> uploadReading(String userId, double temp, double humidity) async {
    try {
      await _db.collection('users').doc(userId).collection('readings').add({
        'temp': temp,
        'humidity': humidity,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print("Data uploaded: $temp°C, $humidity%");
    } catch (e) {
      print("Upload failed: $e");
    }
  }

  // 2. Fetch Last 24h Data for Charts
  Future<Map<String, List<FlSpot>>> fetch24hData(String userId) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(hours: 24));

    try {
      QuerySnapshot snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('readings')
          .where('timestamp', isGreaterThan: yesterday)
          .orderBy('timestamp', descending: false)
          .get();

      List<FlSpot> tempSpots = [];
      List<FlSpot> humSpots = [];

      // We map the X-axis to "Hours ago" (0 to 24) or just timestamp milliseconds
      // For simplicity, let's use: X = index (0, 1, 2...) representing time sequence
      int index = 0;
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        double t = (data['temp'] as num).toDouble();
        double h = (data['humidity'] as num).toDouble();
        
        // Optionally: You can parse 'timestamp' to place points accurately on a time axis
        // For now, sequential indexing works for simple trending
        tempSpots.add(FlSpot(index.toDouble(), t));
        humSpots.add(FlSpot(index.toDouble(), h));
        index++;
      }

      return {'temp': tempSpots, 'humidity': humSpots};
    } catch (e) {
      print("Fetch failed: $e");
      return {'temp': [], 'humidity': []};
    }
  }

  // 3. Delete Data Older than 24h (Run on Init)
  Future<void> cleanupOldData(String userId) async {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    
    try {
      // Find old documents
      QuerySnapshot oldDocs = await _db
          .collection('users')
          .doc(userId)
          .collection('readings')
          .where('timestamp', isLessThan: yesterday)
          .get();

      // Batch delete them
      WriteBatch batch = _db.batch();
      for (var doc in oldDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print("Cleaned up ${oldDocs.docs.length} old records.");
    } catch (e) {
      print("Cleanup failed: $e");
    }
  }
}