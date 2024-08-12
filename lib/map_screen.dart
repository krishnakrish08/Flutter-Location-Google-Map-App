import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_location_app/components/map_pin_pill.dart';
import 'package:flutter_location_app/models/pin_pill_info.dart';
import 'package:flutter_location_app/utils/utils.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = <Marker>{};

// for my drawn routes on the map
  final Set<Polyline> _polyLines = <Polyline>{};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints? polylinePoints;
  String googleAPIKey = '<API_KEY>';

// for my custom marker pins
  BitmapDescriptor? sourceIcon;
  BitmapDescriptor? destinationIcon;

// the user's initial location and current location
// as it moves
  LocationData? currentLocation;

// a reference to the destination location
  LocationData? destinationLocation;

// wrapper around the location API
  Location? location;
  double pinPillPosition = -100;
  PinInformation currentlySelectedPin = PinInformation(
      pinPath: '',
      avatarPath: '',
      location: const LatLng(0, 0),
      locationName: '',
      labelColor: Colors.grey);
  PinInformation? sourcePinInfo;
  PinInformation? destinationPinInfo;

  @override
  void initState() {
    super.initState();

    // create an instance of Location
    location = Location();
    polylinePoints = PolylinePoints();

    // subscribe to changes in the user's location
    // by "listening" to the location's onLocationChanged event
    location?.onLocationChanged.listen((LocationData cLoc) {
      // cLoc contains the lat and long of the
      // current user's position in real time,
      // so we're holding on to it
      currentLocation = cLoc;
      updatePinOnMap();
    });
    // set custom marker pins
    setSourceAndDestinationIcons();
    // set the initial location
    setInitialLocation();
  }

  void setSourceAndDestinationIcons() async {
    BitmapDescriptor.asset(
      const ImageConfiguration(devicePixelRatio: 2.0),
      'assets/images/map_pin_driving.png',
    ).then((onValue) {
      sourceIcon = onValue;
    });

    BitmapDescriptor.asset(
      const ImageConfiguration(devicePixelRatio: 2.0),
      'assets/images/map_pin_destination.png',
    ).then((onValue) {
      destinationIcon = onValue;
    });
  }

  void setInitialLocation() async {
    // set the initial location by pulling the user's
    // current location from the location's getLocation()
    currentLocation = await location?.getLocation();

    // hard-coded destination for this example
    destinationLocation = LocationData.fromMap({
      "latitude": destLocation.latitude,
      "longitude": destLocation.longitude
    });
  }

  void showPinsOnMap() {
    // get a LatLng for the source location
    // from the LocationData currentLocation object
    var pinPosition = LatLng(
      currentLocation?.latitude ?? 0,
      currentLocation?.longitude ?? 0,
    );
    // get a LatLng out of the LocationData object
    var destPosition = LatLng(
      destinationLocation?.latitude ?? 0,
      destinationLocation?.longitude ?? 0,
    );

    sourcePinInfo = PinInformation(
      locationName: "Start Location",
      location: sourceLocation,
      pinPath: "assets/driving_pin.png",
      avatarPath: "assets/friend1.jpg",
      labelColor: Colors.orangeAccent,
    );

    destinationPinInfo = PinInformation(
      locationName: "End Location",
      location: destLocation,
      pinPath: "assets/destination_map_marker.png",
      avatarPath: "assets/friend2.jpg",
      labelColor: Colors.greenAccent,
    );

    // add the initial source location pin
    _markers.add(Marker(
      markerId: const MarkerId('sourcePin'),
      position: pinPosition,
      onTap: () {
        setState(() {
          currentlySelectedPin = sourcePinInfo!;
          pinPillPosition = 0;
        });
      },
      icon: sourceIcon ?? BitmapDescriptor.defaultMarker,
    ));

    // destination pin
    _markers.add(Marker(
      markerId: const MarkerId('destPin'),
      position: destPosition,
      onTap: () {
        setState(() {
          currentlySelectedPin = destinationPinInfo!;
          pinPillPosition = 0;
        });
      },
      icon: destinationIcon ?? BitmapDescriptor.defaultMarker,
    ));

    // set the route lines on the map from source to destination
    // for more info follow this tutorial
    setPolyLines();
  }

  void setPolyLines() async {
    // List<PointLatLng> result = await polylinePoints.getRouteBetweenCoordinates(
    //   googleAPIKey,
    //   currentLocation.latitude,
    //   currentLocation.longitude,
    //   destinationLocation.latitude,
    //   destinationLocation.longitude,
    // );

    PolylineResult? result = await polylinePoints?.getRouteBetweenCoordinates(
        request: PolylineRequest(
      origin: PointLatLng(
        currentLocation?.latitude ?? 0,
        currentLocation?.longitude ?? 0,
      ),
      destination: PointLatLng(
        destinationLocation?.latitude ?? 0,
        destinationLocation?.longitude ?? 0,
      ),
      mode: TravelMode.driving,
    ));

    if (result != null && result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }

      setState(() {
        _polyLines.add(Polyline(
          width: 2, // set the width of the polyLines
          polylineId: const PolylineId("poly"),
          color: const Color.fromARGB(255, 40, 122, 198),
          points: polylineCoordinates,
        ));
      });
    }
  }

  void updatePinOnMap() async {
    // create a new CameraPosition instance
    // every time the location changes, so the camera
    // follows the pin as it moves with an animation
    CameraPosition cPosition = CameraPosition(
      zoom: cameraZoom,
      tilt: cameraTilt,
      bearing: cameraBearing,
      target: LatLng(
        currentLocation?.latitude ?? 0,
        currentLocation?.longitude ?? 0,
      ),
    );
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(cPosition));
    // do this inside the setState() so Flutter gets notified
    // that a widget update is due
    setState(() {
      // updated position
      var pinPosition = LatLng(
        currentLocation?.latitude ?? 0,
        currentLocation?.longitude ?? 0,
      );

      sourcePinInfo?.location = pinPosition;

      // the trick is to remove the marker (by id)
      // and add it again at the updated location
      _markers.removeWhere((m) => m.markerId.value == 'sourcePin');
      _markers.add(Marker(
        markerId: const MarkerId('sourcePin'),
        onTap: () {
          setState(() {
            currentlySelectedPin = sourcePinInfo!;
            pinPillPosition = 0;
          });
        },
        position: pinPosition, // updated position
        icon: sourceIcon ?? BitmapDescriptor.defaultMarker,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    CameraPosition initialCameraPosition = const CameraPosition(
      zoom: cameraZoom,
      tilt: cameraTilt,
      bearing: cameraBearing,
      target: sourceLocation,
    );

    if (currentLocation != null) {
      initialCameraPosition = CameraPosition(
        target: LatLng(
          currentLocation?.latitude ?? 0,
          currentLocation?.longitude ?? 0,
        ),
        zoom: cameraZoom,
        tilt: cameraTilt,
        bearing: cameraBearing,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            myLocationEnabled: true,
            compassEnabled: true,
            tiltGesturesEnabled: false,
            markers: _markers,
            polylines: _polyLines,
            mapType: MapType.normal,
            initialCameraPosition: initialCameraPosition,
            onTap: (LatLng loc) {
              pinPillPosition = -100;
            },
            onMapCreated: (GoogleMapController controller) {
              controller.setMapStyle(mapStyles);
              _controller.complete(controller);
              // my map has completed being created;
              // i'm ready to show the pins on the map
              showPinsOnMap();
            },
          ),
          MapPinPillComponent(
            pinPillPosition: pinPillPosition,
            currentlySelectedPin: currentlySelectedPin,
          )
        ],
      ),
    );
  }
}
