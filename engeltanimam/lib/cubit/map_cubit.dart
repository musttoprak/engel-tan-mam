import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../constants/app_colors.dart';

class MapCubit extends Cubit<MapState> {
  GoogleMapController? mapController;
  bool isLoading = true;
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPiKey = "AIzaSyCBWnZj5N6sGEpN-HzAPO5MZdSHspnDmZc";
  Map<PolylineId, Polyline> polylines = {};
  Set<Marker> allMarkers = {};
  Set<Marker> markers = {};
  LocationData? currentLocation;
  BuildContext context;
  AnimationController animationController;

  MapCubit(this.context,this.animationController)
      : super(MapInitialState()) {
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    Location location = Location();
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    location.getLocation().then((value) async {
      currentLocation = value;
      emit(MapLocationState(currentLocation!));
      changeLoadingView();
    });
  }

  Future<BitmapDescriptor> getCustomMarkerIcon(String imagePath) async {
    final ByteData byteData = await rootBundle.load(imagePath);
    final Uint8List imageData = byteData.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(imageData);
  }

  void addMarker(LatLng position) {
    if (markers.length < 2) {
      Marker marker = Marker(
        markerId: MarkerId('${position.latitude}-${position.longitude}'),
        position: position,
        onTap: () {
          removeMarker(MarkerId('${position.latitude}-${position.longitude}'));
        },
      );
      markers.add(marker);
      allMarkers.add(marker);
      //changeButtonText(true);
    } else {
      //changeButtonText(false);
    }
  }

  void removeMarker(MarkerId markerId) {
    markers.removeWhere((element) => element.markerId == markerId);
    allMarkers.removeWhere((element) => element.markerId == markerId);
    polylines = {};
    emit(MapRemoveMarkerState(polylines, markers));
  }

  void removeMarkerAll() {
    allMarkers.removeAll(markers);
    markers = {};
    polylines = {};
    emit(MapRemoveMarkerState(polylines, markers));
  }

  Future<void> polyWalk(LatLng e) async {
    List<LatLng> polylineCoordinates = [];

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleAPiKey,
      PointLatLng(currentLocation!.latitude!, currentLocation!.longitude!),
      PointLatLng(e.latitude, e.longitude),
      travelMode: TravelMode.walking,
    );

    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    } else {
      //changeButtonText(false);
    }
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: AppColors.headerTextColor,
      points: polylineCoordinates,
      jointType: JointType.round,
      patterns: [PatternItem.dot, PatternItem.gap(10)],
      width: 8,
    );
    polylines[id] = polyline;
    return;
  }

  Future<void> poly(bool isCurrentLocation) async {
    List<LatLng> polylineCoordinates = [];
    PolylineResult result;
    if (isCurrentLocation) {
      result = await polylinePoints.getRouteBetweenCoordinates(
        googleAPiKey,
        PointLatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        PointLatLng(markers.elementAt(0).position.latitude,
            markers.elementAt(0).position.longitude),
        travelMode: TravelMode.driving,
      );
    } else {
      result = await polylinePoints.getRouteBetweenCoordinates(
        googleAPiKey,
        PointLatLng(markers.elementAt(0).position.latitude,
            markers.elementAt(0).position.longitude),
        PointLatLng(markers.elementAt(1).position.latitude,
            markers.elementAt(1).position.longitude),
        travelMode: TravelMode.driving,
      );
    }
    addPolyLine(polylineCoordinates);
  }

  addPolyLine(List<LatLng> polylineCoordinates) {
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: AppColors.headerTextColor,
      points: polylineCoordinates,
      width: 8,
    );
    polylines[id] = polyline;
  }

  void _zoomToPolygon(LatLng firstMarkerPosition, LatLng secondMarkerPosition) {
    if (mapController != null) {
      List<LatLng> points = [];
      polylines.forEach((key, value) {
        points.addAll(value.points);
      });
      LatLngBounds bounds = _calculateBoundsWithPolygon(points);
      // Yeni bir LatLngBounds oluştururken, üst kısmına 400 piksel ekleyelim
      double topPadding = 100.0;
      LatLngBounds paddedBounds = LatLngBounds(
        southwest: LatLng(bounds.southwest.latitude, bounds.southwest.longitude),
        northeast: LatLng(bounds.northeast.latitude + (topPadding / 111000), bounds.northeast.longitude),
      );

      mapController!.animateCamera(CameraUpdate.newLatLngBounds(paddedBounds, 10));
    }
  }

  LatLngBounds _calculateBoundsWithPolygon(List<LatLng> polygonPoints) {
    double minLat = polygonPoints[0].latitude;
    double maxLat = polygonPoints[0].latitude;
    double minLng = polygonPoints[0].longitude;
    double maxLng = polygonPoints[0].longitude;

    for (int i = 1; i < polygonPoints.length; i++) {
      if (polygonPoints[i].latitude > maxLat) {
        maxLat = polygonPoints[i].latitude;
      } else if (polygonPoints[i].latitude < minLat) {
        minLat = polygonPoints[i].latitude;
      }
      if (polygonPoints[i].longitude > maxLng) {
        maxLng = polygonPoints[i].longitude;
      } else if (polygonPoints[i].longitude < minLng) {
        minLng = polygonPoints[i].longitude;
      }
    }

    return LatLngBounds(northeast: LatLng(maxLat, maxLng), southwest: LatLng(minLat, minLng));
  }

  void changeLoadingView() {
    isLoading = !isLoading;
    emit(MapLoadingState(isLoading));
  }

  void mapsControllerInitalize(GoogleMapController mapController) {
    this.mapController = mapController;
  }
}

abstract class MapState {}

class MapInitialState extends MapState {}

class MapLoadingState extends MapState {
  final bool isLoading;

  MapLoadingState(this.isLoading);
}

class MapActiveState extends MapState {
  final bool isLoading;

  MapActiveState(this.isLoading);
}

class MapLocationState extends MapState {
  final LocationData value;

  MapLocationState(this.value);
}

class MapRemoveMarkerState extends MapState {
  final Map<PolylineId, Polyline> polylines;
  final Set<Marker> markers;

  MapRemoveMarkerState(this.polylines, this.markers);
}

