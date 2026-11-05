import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shellObserverProvider =
    Provider((ref) => RouteObserver<ModalRoute<dynamic>>());
