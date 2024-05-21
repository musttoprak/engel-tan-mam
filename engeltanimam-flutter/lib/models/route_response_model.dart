import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteResponseModel {
  final String distance;
  final String duration;
  final List<RouteStepModel> steps;

  RouteResponseModel({
    required this.distance,
    required this.duration,
    required this.steps,
  });

  factory RouteResponseModel.fromJson(Map<String, dynamic> json) {
    return RouteResponseModel(
      distance: json['distance'].toString(),
      duration: json['duration'].toString(),
      steps: List<RouteStepModel>.from(json['steps'].map((step) => RouteStepModel.fromJson(step))),
    );
  }
}

class RouteStepModel {
  final String distanceText;
  final int distanceValue;
  final String durationText;
  final int durationValue;
  final LatLng endLocation;
  final String htmlInstructions;
  final String? maneuver;
  final String polylinePoints;
  final LatLng startLocation;
  final String travelMode;

  RouteStepModel({
    required this.distanceText,
    required this.distanceValue,
    required this.durationText,
    required this.durationValue,
    required this.endLocation,
    required this.htmlInstructions,
    this.maneuver,
    required this.polylinePoints,
    required this.startLocation,
    required this.travelMode,
  });

  factory RouteStepModel.fromJson(Map<String, dynamic> json) {
    return RouteStepModel(
      distanceText: json['distance']['text'],
      distanceValue: json['distance']['value'],
      durationText: json['duration']['text'],
      durationValue: json['duration']['value'],
      endLocation: LatLng(json['end_location']['lat'], json['end_location']['lng']),
      htmlInstructions: json['html_instructions'],
      maneuver: json['maneuver'],
      polylinePoints: json['polyline']['points'],
      startLocation: LatLng(json['start_location']['lat'], json['start_location']['lng']),
      travelMode: json['travel_mode'],
    );
  }
}
