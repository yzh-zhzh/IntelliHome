import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class SensorService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> uploadReading(String userId, double temp, double humidity) async {
    try {
      await _db.collection('users').doc(userId).collection('readings').add({
        'temp': temp,
        'humidity': humidity,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      await updateLiveStatus(userId, temp, humidity);

      print("Data uploaded & Status updated: $temp°C, $humidity%");
    } catch (e) {
      print("Upload failed: $e");
    }
  }

  Future<void> updateLiveStatus(String userId, double temp, double humidity) async {
    try {
      await _db.collection('users').doc(userId).collection('status').doc('latest').set({
        'temp': temp,
        'humidity': humidity,
        'last_seen': FieldValue.serverTimestamp(),
        'is_online': true,
      });
    } catch (e) {
      print("Status update failed: $e");
    }
  }

  Future<int> batchUploadReadings(String userId, List<Map<String, dynamic>> readings) async {
    if (readings.isEmpty) return 0;
    
    WriteBatch batch = _db.batch();
    int count = 0;

    for (var reading in readings) {
      var docRef = _db.collection('users').doc(userId).collection('readings').doc();
      batch.set(docRef, {
        'temp': reading['temp'],
        'humidity': reading['humidity'],
        'timestamp': FieldValue.serverTimestamp(), 
      });
      count++;
      
      if (count % 450 == 0) {
        await batch.commit();
        batch = _db.batch();
      }
    }
    
    await batch.commit();
    print("Batch uploaded $count records.");
    return count;
  }

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
      int index = 0;
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        double t = (data['temp'] as num).toDouble();
        double h = (data['humidity'] as num).toDouble();
        
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

  Future<void> cleanupOldData(String userId) async {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    try {
      QuerySnapshot oldDocs = await _db
          .collection('users')
          .doc(userId)
          .collection('readings')
          .where('timestamp', isLessThan: yesterday)
          .get();

      WriteBatch batch = _db.batch();
      for (var doc in oldDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print("Cleanup failed: $e");
    }
  }
}