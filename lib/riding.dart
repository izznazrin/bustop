import 'package:bustop/InBus.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class Riding extends StatefulWidget {
  final String nearestBusStop;

  const Riding(
      {Key key = const Key('defaultKey'),
      this.nearestBusStop = 'defaultBusStop'})
      : super(key: key);

  @override
  State<Riding> createState() => _RidingState();
}

class PolylineData {
  final Polyline polyline;
  final double distance;

  PolylineData(this.polyline, this.distance);
}

class _RidingState extends State<Riding> {
  bool showMap = false;
  bool isButtonPressed = false;

  String? selectedOption = 'Choose Destination';
  List<String> options = [
    'Choose Destination',
    'Kolej Kediaman Pewira',
    'PKU & CARE',
    'G3 (Back)',
    'FKEE',
    'Kolej Kediaman Tun Fatimah',
    'Kolej Kediaman Tun Dr. Ismail',
    'G3 (Front)',
    'Library',
    'Dewan Sultan Ibrahim',
    'FPTP',
    'FPTV',
    'FKAAB',
    'FKAAB 2',
    'FKEE (New Building)',
    'FKMP',
    'FKEE 2',
    'Arked',
    'ATM',
  ];

  final Map<String, LatLng> busStopLocations = {
    'Kolej Kediaman Pewira': LatLng(1.861775, 103.099222),
    'PKU & CARE': LatLng(1.8561335089285704, 103.08425674117098),
    'G3 (Back)': LatLng(1.8578237774971171, 103.08711181778779),
    'FKEE': LatLng(1.859955, 103.089037),
    'Kolej Kediaman Tun Fatimah': LatLng(1.863189, 103.088996),
    'Kolej Kediaman Tun Dr. Ismail': LatLng(1.862917, 103.089213),
    'G3 (Front)': LatLng(1.859658, 103.086544),
    'Library': LatLng(1.858096, 103.083229),
    'Dewan Sultan Ibrahim': LatLng(1.858260, 103.081370),
    'FPTP': LatLng(1.861238, 103.081408),
    'FPTV': LatLng(1.862954, 103.081570),
    'FKAAB': LatLng(1.864361, 103.083192),
    'FKAAB 2': LatLng(1.864114, 103.085262),
    'FKEE (New Building)': LatLng(1.860598, 103.086141),
    'FKMP': LatLng(1.861335, 103.087968),
    'FKEE 2': LatLng(1.860276, 103.089091),
    'Arked': LatLng(1.857055, 103.087494),
    'ATM': LatLng(1.854348, 103.086318),
  };

  final markerId = 'busMarker';
  LatLng initialBus = LatLng(1.856202, 103.083296);
  Map<String, Marker> _markers = {};

  Future<void> addMarker(String id, LatLng location, String busstopname) async {
    var markerIcon;

    if (id == markerId) {
      markerIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(),
        'assets/images/busicon.png',
      );
    } else {
      markerIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(),
        'assets/images/busstopicon.png',
      );
    }

    var marker = Marker(
      markerId: MarkerId(id),
      position: location,
      infoWindow: InfoWindow(
        title: busstopname,
      ),
      icon: markerIcon,
    );

    _markers[id] = marker;
    setState(() {});
  }

  Map<PolylineId, PolylineData> _polylines = {};
  double remainingTime = 0.0;

  void updateMarkerPosition(Position position) async {
    LatLng newPosition = LatLng(position.latitude, position.longitude);
    Marker updatedMarker = _markers[markerId]!;
    updatedMarker = updatedMarker.copyWith(positionParam: newPosition);
    _markers[markerId] = updatedMarker;

    if (busStopLocations.containsKey(widget.nearestBusStop)) {
      final LatLng busStopLocation = busStopLocations[widget.nearestBusStop]!;
      double distance = distanceBetween(newPosition, busStopLocation);
      if (distance <= 10000) {
        // If the bus is within 100 meters of the bus stop, request directions
        String apiKey = 'AIzaSyCWC0D4MexVfU7wBRq_jwzu0HCUaT-3_m8';
        String apiUrl = 'https://maps.googleapis.com/maps/api/directions/json?'
            'origin=${newPosition.latitude},${newPosition.longitude}'
            '&destination=${busStopLocation.latitude},${busStopLocation.longitude}'
            '&key=$apiKey';

        // Make an HTTP GET request to the Directions API
        http.Response response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          // Parse the JSON response
          Map<String, dynamic> data = jsonDecode(response.body);
          List<dynamic> routes = data['routes'];
          if (routes.isNotEmpty) {
            // Extract the polyline points from the response
            String encodedPoints = routes[0]['overview_polyline']['points'];

            // Decode the polyline points
            List<LatLng> polylinePoints = decodePolyline(encodedPoints);

            // Create a unique polyline ID
            PolylineId polylineId = PolylineId('busPolyline');

            // Create a Polyline object
            Polyline polyline = Polyline(
              polylineId: polylineId,
              color: Colors.blue,
              width: 3,
              points: polylinePoints,
            );

            // Create a PolylineData object with the polyline and distance
            PolylineData polylineData = PolylineData(
              polyline,
              calculatePolylineDistance(polylinePoints),
            );

            // Add the polyline data to the map
            _polylines[polylineId] = polylineData;

            // Add the polyline to the map
            //_polylines[polylineId] = polyline;

            // Calculate remaining time based on distance
            double remainingDistance = polylineData.distance;
            double remainingTime = calculateRemainingTime(remainingDistance);

            setState(() {
              // Assign the calculated remaining time to the variable
              this.remainingTime = remainingTime;
            });
          }
        }
      }
    }

    setState(() {});
  }

  // Function to decode the polyline points
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> polylinePoints = [];

    int index = 0;
    int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      double latLngOffset =
          1e-5; // Offset to convert integer coordinates to LatLng values
      double latValue = lat * latLngOffset;
      double lngValue = lng * latLngOffset;
      LatLng point = LatLng(latValue, lngValue);
      polylinePoints.add(point);
    }

    return polylinePoints;
  }

  double distanceBetween(LatLng start, LatLng end) {
    const int earthRadius = 6371000; // in meters
    double lat1 = start.latitude;
    double lon1 = start.longitude;
    double lat2 = end.latitude;
    double lon2 = end.longitude;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;
    return distance;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  double calculatePolylineDistance(List<LatLng> polylinePoints) {
    double totalDistance = 0.0;
    LatLng previousPoint = polylinePoints[0];

    for (int i = 1; i < polylinePoints.length; i++) {
      LatLng currentPoint = polylinePoints[i];
      double segmentDistance = distanceBetween(previousPoint, currentPoint);
      totalDistance += segmentDistance;
      previousPoint = currentPoint;
    }

    return totalDistance;
  }

  double calculateRemainingTime(double distance) {
    double busSpeed = 10.0;
    return distance / busSpeed;
  }

  //bus plate number
  String busPlateNumber = '';
  Future<String> getBusPlateNumber() async {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('Driver')
        .doc('driver1')
        .get();
    if (snapshot.exists) {
      busPlateNumber = snapshot['bus_id'] ??
          ''; // Assign the value directly to the outer variable
      return busPlateNumber;
    } else {
      return '';
    }
  }

  Stream<int> getPassengerCountStream() {
    return FirebaseFirestore.instance
        .collection('Passenger')
        .where('passenger_inbus', isEqualTo: true)
        .snapshots()
        .map((QuerySnapshot snapshot) => snapshot.size);
  }

  late User? _user;
  late String _studentName;
  Future<void> _loadStudentName() async {
    final studentDoc = await FirebaseFirestore.instance
        .collection('Student')
        .where('student_uid', isEqualTo: _user!.uid)
        .limit(1)
        .get();
    if (studentDoc.docs.isNotEmpty) {
      final studentData = studentDoc.docs.first.data();
      setState(() {
        _studentName = studentData['student_name'] ?? 'Unknown';
      });
    }
  }

  @override
  void initState() {
    super.initState();

    if (busStopLocations.containsKey(widget.nearestBusStop)) {
      final LatLng location = busStopLocations[widget.nearestBusStop]!;
      addMarker('busstop1', location, 'HENTIAN 1: ${widget.nearestBusStop}');
    }

    // Add the bus marker
    addMarker(markerId, initialBus, '');

    // Listen to changes in driver location from Firebase
    FirebaseFirestore.instance
        .collection('Driver')
        .doc('driver1')
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          GeoPoint geoPoint = snapshot.get('driver_location');
          Position position = Position(
            latitude: geoPoint.latitude,
            longitude: geoPoint.longitude,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          );
          updateMarkerPosition(position);
        }
      },
    );
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _loadStudentName();
    }
  }

  Widget buildMapContainer() {
    return Container(
      height: 460,
      margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Upcoming Bus',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 25,
              ),
            ),
          ),
          Container(
            height: 375,
            margin: EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.4),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.all(20),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: busStopLocations[widget.nearestBusStop]!,
                        zoom: 14,
                      ),
                      markers: Set<Marker>.of(_markers.values),
                      polylines: _polylines.values
                          .map((polylineData) => polylineData.polyline)
                          .toSet(),
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(left: 20),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Estimated arrival time: ${remainingTime.toStringAsFixed(0)} seconds',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StreamBuilder<int>(
                          stream: getPassengerCountStream(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final passengerCount = snapshot.data;
                              return Text(
                                'Number of passengers: $passengerCount',
                                style: TextStyle(fontSize: 18),
                              );
                            } else if (snapshot.hasError) {
                              return Text(
                                'Error retrieving passenger count',
                                style: TextStyle(fontSize: 18),
                              );
                            } else {
                              return CircularProgressIndicator(); // Display a loading indicator while waiting for data
                            }
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FutureBuilder<String>(
                          future: getBusPlateNumber(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final busPlateNumber = snapshot.data;
                              return Text(
                                'Bus plate number: $busPlateNumber',
                                style: TextStyle(fontSize: 18),
                              );
                            } else if (snapshot.hasError) {
                              return Text(
                                'Error retrieving bus plate number',
                                style: TextStyle(fontSize: 18),
                              );
                            } else {
                              return CircularProgressIndicator(); // Display a loading indicator while waiting for data
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.fromLTRB(20, 10, 20, 10),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            // Get the current timestamp
                            Timestamp passengerDate = Timestamp.now();

                            String? studentName = _studentName;

                            // Create a new document in the "Passenger" collection
                            CollectionReference passengerCollection =
                                FirebaseFirestore.instance
                                    .collection('Passenger');

                            DocumentReference newDocumentRef =
                                await passengerCollection.add({
                              'bus_id': busPlateNumber,
                              'passenger_date': passengerDate,
                              'passenger_destination': selectedOption,
                              'passenger_inbus': true,
                              'student_name': studentName,
                            });

                            // Navigate to the "InBus" screen and pass the document ID as a parameter
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InBus(
                                    documentId: newDocumentRef.id,
                                    selectedOption: selectedOption!),
                              ),
                            );
                          },
                          child: Text(
                            'Check-in',
                            style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDestinationChosen = selectedOption != 'Choose Destination';

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: EdgeInsets.only(left: 80),
          child: Text('Journey'),
        ),
      ),
      backgroundColor: Colors.grey[300],
      body: SingleChildScrollView(
        child: Column(
          children: [
            Material(
              elevation: 4,
              child: Container(
                height: 50,
                color: Colors.white,
                child: Row(
                  children: [
                    Container(
                      margin: EdgeInsets.all(10),
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        border: Border.all(
                          color: Colors.blue,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'At Bus Stop',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.fromLTRB(0, 10, 10, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.black,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '  ' + widget.nearestBusStop + '  ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(20),
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(15),
                      child: Padding(
                        padding: EdgeInsets.all(15),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_pin,
                              size: 40,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: IgnorePointer(
                                ignoring: isButtonPressed,
                                child: Opacity(
                                  opacity: isButtonPressed ? 0.5 : 1.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: DropdownButton<String>(
                                      value: selectedOption,
                                      onChanged: isButtonPressed
                                          ? null // Disable the dropdown button if button is pressed
                                          : (String? newValue) {
                                              setState(
                                                () {
                                                  selectedOption = newValue;
                                                  isDestinationChosen =
                                                      selectedOption !=
                                                          'Choose Destination';
                                                },
                                              );
                                            },
                                      underline:
                                          Container(), // Remove the default underline
                                      items:
                                          options.map<DropdownMenuItem<String>>(
                                        (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Text(
                                                value,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (!showMap && isDestinationChosen)
              Container(
                margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      showMap = true;
                      isButtonPressed = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    textStyle:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    minimumSize: Size(
                      double.infinity,
                      60,
                    ),
                  ),
                  child: Text(
                    'View Upcoming Bus',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (showMap) buildMapContainer(),
          ],
        ),
      ),
    );
  }
}
