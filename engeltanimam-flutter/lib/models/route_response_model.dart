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
  final String distance;
  final String duration;
  final String recipe;

  RouteStepModel({
    required this.distance,
    required this.duration,
    required this.recipe,
  });

  factory RouteStepModel.fromJson(Map<String, dynamic> json) {
    return RouteStepModel(
      distance: json['distance'].toString(),
      duration: json['duration'].toString(),
      recipe: json['recipe'],
    );
  }
}