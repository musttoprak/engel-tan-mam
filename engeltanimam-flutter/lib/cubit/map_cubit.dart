import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../constants/app_colors.dart';
import '../models/route_response_model.dart';

class MapCubit extends Cubit<MapState> {
  final String routeText;
  GoogleMapController? mapController;
  bool isLoading = true;
  PolylinePoints polylinePoints = PolylinePoints();
  String googleAPiKey = "AIzaSyBChasi4i5uXfZSnwh5mvZWIN-d8yV7cto";
  StreamSubscription<LocationData>? locationSubscription;
  StreamSubscription<geo.Position>? positionStreamSubscription;
  LatLng? previousPosition;
  Map<PolylineId, Polyline> polylines = {};
  Set<Marker> allMarkers = {};
  Set<Marker> markers = {};
  LocationData? currentLocation;
  BuildContext context;
  AnimationController animationController;
  RouteResponseModel? result;
  bool isAlertShown = false;
  String directionMessage = "";
  double _currentBearing = 0;

  MapCubit(this.context, this.routeText, this.animationController)
      : super(MapInitialState()) {
    getCurrentLocation();
  }

  Future<void> getRouteSteps(String origin, String destination) async {
    const baseUrl = "https://maps.googleapis.com/maps/api/directions/json?";

    final Dio dio = Dio();
    final apiUrl =
        "${baseUrl}origin=$origin&destination=$destination&mode=walking&language=tr&key=$googleAPiKey";
    final response = await dio.get(apiUrl);
    if (response.statusCode == 200) {
      final responseData = response.data;
      if (responseData != null && responseData['routes'].isNotEmpty) {
        final legs = responseData['routes'][0]['legs'][0];

        final distanceMetersLegs = legs['distance']['value'];
        final durationSecondsLegs = legs['duration']['value'];

        final arr = distanceAndDurationCalculator(
            distanceMetersLegs, durationSecondsLegs);

        final steps = responseData['routes'][0]['legs'][0]['steps'];
        final stepsList = <RouteStepModel>[];
        for (final step in steps) {
          final distanceMeters = step['distance']['value'];
          final durationSeconds = step['duration']['value'];

          final arrSteps =
              distanceAndDurationCalculator(distanceMeters, durationSeconds);

          final recipe = stripTags(step['html_instructions']); // text hali
          stepsList.add(
            RouteStepModel(
              distance: arrSteps[0].toString(),
              duration: arrSteps[1].toString(),
              recipe: recipe,
            ),
          );
        }
        result = RouteResponseModel(
          distance: arr[0].toString(),
          duration: arr[1].toString(),
          steps: stepsList,
        );
        print(result!.steps.length);

        emit(MapResultState(result!));
      } else {
        print('error : Rota bulunamadı.');
      }
    } else {
      print('error :API\'ye istek gönderilirken bir hata oluştu.');
    }
  }

  List<dynamic> distanceAndDurationCalculator(
      int distanceMeters, int durationSeconds) {
    final distanceKilometers = distanceMeters / 1000;
    final durationMinutes = (durationSeconds / 60).round();

    return [distanceKilometers, durationMinutes];
  }

  String stripTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

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
        await _initPositionTracking();
        await getRouteSteps(
            "${currentLocation!.latitude!},${currentLocation!.longitude!}",
            "${location['lat']},${location['lng']}");
        await _startTrackingUser();
      } else {
        print(jsonEncode({"error": "Sonuç bulunamadı."}));
      }
    }
  }

  Future<void> _startTrackingUser() async {
    Location location = Location();
    locationSubscription = location.onLocationChanged.listen((locationData) {
      _checkIfUserIsOffRoute(locationData);
    });
  }

  Future<void> _checkIfUserIsOffRoute(LocationData locationData) async {
    LatLng currentPosition =
        LatLng(locationData.latitude!, locationData.longitude!);
    double distance = await _calculateDistanceToPolyline(currentPosition);

    if (previousPosition != null) {
      if (distance > 20) {
        // 20 metre sapma toleransı
        _showUserOffRouteAlert(currentPosition);
      } else {
        isAlertShown = false; // Sapma düzeltildiğinde bayrağı sıfırla
      }
      previousPosition = currentPosition;
    } else {
      previousPosition = currentPosition;
    }
  }

  Future<double> _calculateDistanceToPolyline(LatLng position) async {
    double minDistance = double.infinity;

    for (Polyline polyline in polylines.values) {
      for (LatLng point in polyline.points) {
        double distance = geo.Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          point.latitude,
          point.longitude,
        );
        if (distance < minDistance) {
          minDistance = distance;
        }
      }
    }

    return minDistance;
  }

  void _showUserOffRouteAlert(LatLng currentPosition) {
    if (!isAlertShown) {
      directionMessage = _calculateDirectionMessage(currentPosition);
      print(directionMessage);
      isAlertShown = true; // Alert gösterildiğini işaretle
      emit(MapDirectionChange(directionMessage));
    }
  }

  String _calculateDirectionMessage(LatLng currentPosition) {
    if (previousPosition == null) return "Rotaya dönün.";

    // Kullanıcının mevcut yönünü hesaplayın
    double userBearing = geo.Geolocator.bearingBetween(
      previousPosition!.latitude,
      previousPosition!.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );

    // En yakın noktayı bulun
    LatLng nearestPoint = _findNearestPointOnRoute(currentPosition);

    // Hedef noktaya olan yönü hesaplayın
    double targetBearing = geo.Geolocator.bearingBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      nearestPoint.latitude,
      nearestPoint.longitude,
    );

    // Yön farkını hesaplayın
    double bearingDifference = targetBearing - userBearing;

    // Yönlendirme mesajı oluşturun
    if (bearingDifference.abs() < 20) {
      return "Doğru yoldasınız, devam edin.";
    } else if (bearingDifference > 0) {
      if (bearingDifference > 45 && bearingDifference < 135) {
        return "Sağa dönün.";
      } else {
        return "Doğru yoldan çıkıyorsunuz, sağa dönün.";
      }
    } else {
      if (bearingDifference < -45 && bearingDifference > -135) {
        return "Sola dönün.";
      } else {
        return "Doğru yoldan çıkıyorsunuz, sola dönün.";
      }
    }
  }

  LatLng _findNearestPointOnRoute(LatLng currentPosition) {
    LatLng nearestPoint = polylines.values.first.points.first;
    double minDistance = double.infinity;

    for (Polyline polyline in polylines.values) {
      for (LatLng point in polyline.points) {
        double distance = geo.Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          point.latitude,
          point.longitude,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestPoint = point;
        }
      }
    }

    return nearestPoint;
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
      await getRoute();
      emit(MapLoadingState(false));
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

  Future<void> _initPositionTracking() async {
    try {
      positionStreamSubscription = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.best, // geo. prefixini kaldırın
          distanceFilter: 10, // metre cinsinden minimum hareket mesafesi
        ),
      ).listen((geo.Position position) async {
        // Kullanıcının yeni konumu alındığında yönelimi güncelle
        _currentBearing =
            position.heading ?? 0; // position.heading null kontrolü ekleyin
        await _zoomToRoute(
          LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        );
      });
    } catch (e) {
      print("Position tracking error: $e");
    }
  }

  Future<void> _zoomToRoute(LatLng userPosition) async {
    // Kullanıcının konumu ve baktığı yöne göre haritayı döndür
    CameraPosition cameraPosition = CameraPosition(
      target: userPosition,
      zoom: 19, // Yakınlaştırma seviyesini ayarlayabilirsiniz
      tilt: 60, // Kullanıcının bakış açısını temsil eden tilt değeri
      bearing: _currentBearing,
    );

    // Haritayı hareket ettir
    await mapController!
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
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

  Future<void> mapsControllerInitalize(
      GoogleMapController mapController) async {
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

class MapResultState extends MapState {
  final RouteResponseModel result;

  MapResultState(this.result);
}

class MapDirectionChange extends MapState {
  final String directionText;

  MapDirectionChange(this.directionText);
}
