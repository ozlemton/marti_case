import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

double calculateDistance(LatLng point1, LatLng point2) {
  const earthRadius = 6371000;

  double lat1 = point1.latitude * pi / 180;
  double lon1 = point1.longitude * pi / 180;
  double lat2 = point2.latitude * pi / 180;
  double lon2 = point2.longitude * pi / 180;

  double deltaLat = lat2 - lat1;
  double deltaLon = lon2 - lon1;

  double a = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  double distance = earthRadius * c;
  return distance;
}

Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
  final apiKey = 'AIzaSyDAMV9SWY0un5iz7Edi-MM-CK3QsmQsD48';
  final url = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$apiKey');
  print(url);
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['results'] != null && data['results'].isNotEmpty) {
      var addressComponents = data['results'][0]['address_components'];
      String street = addressComponents[1]["long_name"];
      String neighborhood = addressComponents[2]["long_name"];
      String fullAddress = "$street, $neighborhood";

      return fullAddress.isNotEmpty ? fullAddress : 'Unknown Location';
    } else {
      return 'Unknown Location';
    }
  } else {
    throw Exception('Failed to load address');
  }
}

class MartiTracking extends StatefulWidget {
  const MartiTracking({super.key});

  @override
  State<MartiTracking> createState() => _MartiTrackingState();
}

class _MartiTrackingState extends State<MartiTracking> {
  final locationController = Location();
  StreamSubscription? locationSubscription; // subscription to listen for location updates

  static const googlePlex = LatLng(39.8917, 32.802);
  bool isTracking = true; // tracking status

  LatLng? currentPosition;
  LatLng? previousPosition;
  LatLng? newPosition;
  Set<Marker> markers = {}; // set to hold markers
  List<LatLng> routePoints = []; // list to store the route

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async => await initializeMap());
  }

  Future<void> initializeMap() async {
    await loadRouteFromStorage(); // load routes and markers when application is starting
    await fetchLocationUpdates(); // get location updates
  }

  Future<void> fetchLocationUpdates() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // checking location services
    serviceEnabled = await locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationController.requestService();
      if (!serviceEnabled) {
        debugPrint("Location service is disable");
        return;
      }
    }

    // checking permissions
    permissionGranted = await locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        debugPrint("No permission");
        return;
      }
    }
    // listening location services
    if (isTracking) {
      locationSubscription = locationController.onLocationChanged.listen((currentLocation) async {
        if (currentLocation.latitude != null && currentLocation.longitude != null) {
          newPosition = LatLng(
            currentLocation.latitude!,
            currentLocation.longitude!,
          );
        }
        if (previousPosition != null) {
          final distance = calculateDistance(previousPosition!, newPosition!);
          if (distance >= 100) {
            setState(() {
              currentPosition = newPosition;
              previousPosition = newPosition;

              String markerId = 'marker_${DateTime.now().millisecondsSinceEpoch}';

              markers.add(Marker(
                markerId: MarkerId(markerId),
                position: newPosition!,
                infoWindow: InfoWindow(
                  title: 'New Location',
                  snippet: "Press for details",
                  onTap: () {
                    showMarkerDetails(newPosition!);
                  },
                ),
              ));

              routePoints.add(newPosition!);
              saveRouteToStorage();
            });
          }
        } else {
          setState(() {
            currentPosition = newPosition;
            previousPosition = newPosition;
          });
        }
      });
    } else {
      setState(() {
        currentPosition = newPosition;
        previousPosition = newPosition;
      });
    }
  }

  Future<void> saveRouteToStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> routeString = routePoints.map((latlng) => "${latlng.latitude},${latlng.longitude}").toList();
    await prefs.setStringList("routePoints", routeString);
  }

  Future<void> loadRouteFromStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? routeString = prefs.getStringList("routePoints");

    if (routeString != null) {
      Map<String, String> markerDetailsMap = {};

      for (var point in routePoints) {
        String markerId = 'marker_${DateTime.now().millisecondsSinceEpoch}';
        String address = "";
        try {
          address = await getMarkerDetails(point);
          markerDetailsMap[markerId] = address;
        } catch (e) {
          print("e");
        }
      }

      setState(() {
        routePoints = routeString.map((e) {
          final parts = e.split(',');
          return LatLng(double.parse(parts[0]), double.parse(parts[1]));
        }).toList();

        // markers loading
        markers.clear();
        for (var point in routePoints) {
          String markerId = 'marker_${DateTime.now().millisecondsSinceEpoch}';
          String address = "UnKnown Location";
          try {
            address = markerDetailsMap[markerId] ?? "UnKnown Location";
          } catch (e) {
            print("dsb");
          }
          markers.add(Marker(
            markerId: MarkerId(markerId),
            position: point,
            infoWindow: InfoWindow(
              title: 'Location',
              snippet: address,
            ),
          ));
        }
      });
    }
  }

  Future<String> getMarkerDetails(LatLng position) async {
    String address = await getAddressFromCoordinates(position.latitude, position.longitude);
    return address;
  }

  showMarkerDetails(LatLng position) async {
    String address = await getAddressFromCoordinates(position.latitude, position.longitude);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Details'),
        content: Text('Address: ' + address),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  // start/stop tracking
  void toggleTracking() {
    setState(() {
      if (isTracking) {
        locationSubscription?.cancel();
        isTracking = false;
      } else {
        fetchLocationUpdates();
        isTracking = true;
      }
    });
  }

  void resetRoute() async {
    print("sdgsgdf");
    setState(() {
      routePoints.clear();
      markers.clear();
    });

    //clean
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("routePoints");
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Martı Tracking'), backgroundColor: Colors.blue),
        bottomNavigationBar: Container(
          color: Colors.blue,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: resetRoute,
                  child: Text("Reset Routes"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(150, 50),
                  ),
                ),
                ElevatedButton(
                  onPressed: toggleTracking,
                  child: Text(isTracking ? "Stop Tracking" : "Start Tracking"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(150, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: currentPosition == null
            ? const Center(child: CircularProgressIndicator())
            : GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: googlePlex,
                  zoom: 13,
                ),
                markers: markers,
              ),
      );
}
