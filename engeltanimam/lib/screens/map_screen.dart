import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/app_colors.dart';
import '../cubit/map_cubit.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen>
    with SingleTickerProviderStateMixin, MapsScreenMixin {
  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MapCubit(
          context,
          animationController),
      child: BlocBuilder<MapCubit, MapState>(
        builder: (context, state) {
          return buildScaffold(context);
        },
      ),
    );
  }
}

mixin MapsScreenMixin {
  late GoogleMapController mapController;
  late AnimationController animationController;
  TextEditingController myLocationController = TextEditingController();
  TextEditingController locationController = TextEditingController();

  void _onMapCreated(GoogleMapController controller, BuildContext context) {
    mapController = controller;
    context.read<MapCubit>().mapsControllerInitalize(mapController);
  }

  Scaffold buildScaffold(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        !context.watch<MapCubit>().isLoading
            ? googleMap(context)
            : const Center(child: CircularProgressIndicator()),
        topInfo(context),
        SafeArea(
          child: IconButton(
            icon: const Icon(Icons.arrow_back_outlined,color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        )
      ]),
    );
  }

  GoogleMap googleMap(BuildContext context) {
    LatLng target = LatLng(
        context.read<MapCubit>().currentLocation!.latitude!,
        context.read<MapCubit>().currentLocation!.longitude!);
    return GoogleMap(
      onMapCreated: (controller) => _onMapCreated(controller, context),
      initialCameraPosition: CameraPosition(target: target, zoom: 11.0),
      markers: context.watch<MapCubit>().allMarkers,
      polylines:
      Set<Polyline>.of(context.watch<MapCubit>().polylines.values),
      onTap: (position) {
        context.read<MapCubit>().addMarker(position);
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }

  Visibility topInfo(BuildContext context) {
    return Visibility(
      visible:
          MediaQuery.of(context).viewInsets.bottom <= 0,
      child: Positioned(
        top: 0,
        right: 0,
        left: 0,
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.close,
                      color: AppColors.headerTextColor,
                      size: 18,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
