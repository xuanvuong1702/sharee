import 'package:flutter/material.dart';

/// Shared observer so the shell can reveal its floating navigation when a
/// pushed screen (map, ride tracking, profile detail) is popped.
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();
