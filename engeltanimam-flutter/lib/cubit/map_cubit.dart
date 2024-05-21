import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../constants/app_colors.dart';

class MapCubit extends Cubit<MapState> {
  final String routeText;
  GoogleMapController? mapController;
  bool isLoading = true;
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPiKey = "AIzaSyBChasi4i5uXfZSnwh5mvZWIN-d8yV7cto";
  Map<PolylineId, Polyline> polylines = {};
  Set<Marker> allMarkers = {};
  Set<Marker> markers = {};
  LocationData? currentLocation;
  BuildContext context;
  AnimationController animationController;

  MapCubit(this.context, this.routeText, this.animationController)
      : super(MapInitialState());

  Future<void> getRoute() async {
    const baseUrl =
        "https://maps.googleapis.com/maps/api/place/textsearch/json?";

    final Dio dio = Dio();

    final response = await dio.get(baseUrl, queryParameters: {
      'query': routeText,
      'key': googleAPiKey,
    });

    if (response.statusCode == 200) {
      // API'den gelen yanıtı işleme
      final responseData = response.data;
      if (responseData != null && responseData['results'].isNotEmpty) {
        final formattedAddress =
            responseData['results'][0]['formatted_address'];
        final location = responseData['results'][0]['geometry']['location'];
        final result = {
          "latitude": location['lat'],
          "longitude": location['lng'],
          "formatted_address": formattedAddress,
        };

        // JSON sonucunu ekrana yazdırma
        print(jsonEncode(result));

        // Yol oluşturma
        addMarker(LatLng(location['lat'], location['lng']));
        await polyWalk(LatLng(location['lat'], location['lng']));
        await _zoomToMarkers(
            LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
            LatLng(location['lat'], location['lng']));
      } else {
        print(jsonEncode({"error": "Sonuç bulunamadı."}));
      }
    }
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
      await getRoute();
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
    Marker marker = Marker(
      markerId: MarkerId('${position.latitude}-${position.longitude}'),
      position: position,
      onTap: () {
        removeMarker(MarkerId('${position.latitude}-${position.longitude}'));
      },
    );
    markers.add(marker);
    allMarkers.add(marker);
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

  Future<void> _zoomToMarkers(
      LatLng firstMarkerPosition, LatLng secondMarkerPosition) async {
    // İki konumun sınırlarını belirle
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        firstMarkerPosition.latitude < secondMarkerPosition.latitude
            ? firstMarkerPosition.latitude
            : secondMarkerPosition.latitude,
        firstMarkerPosition.longitude < secondMarkerPosition.longitude
            ? firstMarkerPosition.longitude
            : secondMarkerPosition.longitude,
      ),
      northeast: LatLng(
        firstMarkerPosition.latitude > secondMarkerPosition.latitude
            ? firstMarkerPosition.latitude
            : secondMarkerPosition.latitude,
        firstMarkerPosition.longitude > secondMarkerPosition.longitude
            ? firstMarkerPosition.longitude
            : secondMarkerPosition.longitude,
      ),
    );

    // Harita kamerasını belirtilen sınırlara yakınlaştır
    await mapController!
        .animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    print("zoomlandı");
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

    return LatLngBounds(
        northeast: LatLng(maxLat, maxLng), southwest: LatLng(minLat, minLng));
  }

  void changeLoadingView() {
    isLoading = !isLoading;
    emit(MapLoadingState(isLoading));
  }

  void mapsControllerInitalize(GoogleMapController mapController) {
    this.mapController = mapController;
    print(this.mapController != null);
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
