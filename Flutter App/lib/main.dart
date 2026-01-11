import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ParkingApp());
}

class ParkingApp extends StatelessWidget {
  const ParkingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Parking',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardThemeData(
          elevation: 4,
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
      ),
      home: const ParkingDashboard(),
    );
  }
}

class ParkingDashboard extends StatefulWidget {
  const ParkingDashboard({Key? key}) : super(key: key);

  @override
  State<ParkingDashboard> createState() => _ParkingDashboardState();
}

class _ParkingDashboardState extends State<ParkingDashboard> with SingleTickerProviderStateMixin {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Map<String, ParkingSpot> parkingSpots = {};
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    _setupListeners();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupListeners() {
    // Listen to all spots under Park2/spots
    _database.child('Park2/spots').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final spotsData = Map<String, dynamic>.from(event.snapshot.value as Map);

        setState(() {
          parkingSpots.clear();
          spotsData.forEach((key, value) {
            if (value != null) {
              parkingSpots[key] = ParkingSpot.fromMap(
                Map<String, dynamic>.from(value as Map),
                key,
              );
            }
          });
        });
      }
    });
  }

  int get availableSpots => parkingSpots.values.where((spot) => spot.isAvailable).length;
  int get occupiedSpots => parkingSpots.values.where((spot) => !spot.isAvailable).length;
  int get totalSpots => parkingSpots.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🅿️ Park2 Smart Parking',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Statistics Overview
            _buildStatisticsCard(),
            const SizedBox(height: 20),

            // Parking Lot Visual
            _buildParkingLotVisual(),
            const SizedBox(height: 20),

            // Spot Cards - sorted by spot number (FIXED)
            ...(parkingSpots.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key)))
                .map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ParkingSpotCard(
                spot: entry.value,
                animation: _animationController,
              ),
            ))
                .toList(),

            if (parkingSpots.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading parking data...'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Available',
                  availableSpots.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatItem(
                  'Occupied',
                  occupiedSpots.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
                _buildStatItem(
                  'Total',
                  totalSpots.toString(),
                  Icons.local_parking,
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: totalSpots > 0 ? occupiedSpots / totalSpots : 0,
                minHeight: 12,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(
                  occupiedSpots == totalSpots ? Colors.red : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              occupiedSpots == totalSpots
                  ? 'PARKING FULL!'
                  : '$availableSpots spots available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: occupiedSpots == totalSpots ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 40),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }

  Widget _buildParkingLotVisual() {
    final sortedSpots = parkingSpots.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue[300]),
                const SizedBox(width: 8),
                const Text(
                  'Parking Lot Layout',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Dynamic parking spots layout
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceEvenly,
              children: sortedSpots.map((entry) {
                return _buildParkingSpotVisual(
                  entry.key.toUpperCase(),
                  entry.value.isAvailable,
                  entry.value.distance,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Road/Entrance indicator
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_upward, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'ENTRANCE',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_upward, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkingSpotVisual(String label, bool available, double distance) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 120,
          decoration: BoxDecoration(
            color: available ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            border: Border.all(
              color: available ? Colors.green : Colors.red,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                available ? Icons.check_circle_outline : Icons.directions_car,
                size: 40,
                color: available ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: available ? Colors.green : Colors.red,
                ),
              ),
              Text(
                '${distance.toStringAsFixed(0)}cm',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: available ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            available ? 'FREE' : 'OCCUPIED',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class ParkingSpot {
  final String id;
  final double distance;
  final String status;

  ParkingSpot({
    required this.id,
    required this.distance,
    required this.status,
  });

  bool get isAvailable => status.toUpperCase() == 'AVAILABLE';

  factory ParkingSpot.fromMap(Map<String, dynamic> map, String id) {
    return ParkingSpot(
      id: id,
      distance: (map['distance'] ?? 0).toDouble(),
      status: map['status'] ?? 'UNKNOWN',
    );
  }
}

class ParkingSpotCard extends StatelessWidget {
  final ParkingSpot spot;
  final AnimationController animation;

  const ParkingSpotCard({
    Key? key,
    required this.spot,
    required this.animation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isAvailable = spot.isAvailable;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Card(
          color: isAvailable
              ? const Color(0xFF1E1E1E)
              : Colors.red.withOpacity(0.1 + (animation.value * 0.1)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Parking Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAvailable ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isAvailable ? Icons.local_parking : Icons.directions_car,
                    size: 40,
                    color: isAvailable ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 20),
                // Spot Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.id.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isAvailable ? Icons.check_circle : Icons.cancel,
                            size: 20,
                            color: isAvailable ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            spot.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isAvailable ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.straighten,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Distance: ${spot.distance.toStringAsFixed(1)} cm',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Indicator
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAvailable ? Colors.green : Colors.red,
                    boxShadow: [
                      if (!isAvailable)
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5 + (animation.value * 0.5)),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      else
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Icon(
                    isAvailable ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}