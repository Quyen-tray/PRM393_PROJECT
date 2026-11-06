import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';

final locationProvider =
    Provider<Future<Position> Function()>((ref) => actualLocation);

Future<Position> actualLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const ApiException(
      message: 'GPS đang tắt. Hãy bật dịch vụ vị trí trong cài đặt thiết bị.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const ApiException(
      message: 'Quyền vị trí đã bị tắt. Mở cài đặt ứng dụng để cấp lại quyền.',
    );
  }
  if (permission == LocationPermission.denied) {
    throw const ApiException(
      message: 'Cần quyền vị trí để kiểm tra khoảng cách tới cửa hàng.',
    );
  }
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 25),
      ),
    );
  } on TimeoutException {
    throw const ApiException(
        code: 'GPS_UNAVAILABLE',
        message:
            'Chưa lấy được vị trí GPS. Hãy bật dịch vụ vị trí và thử lại ở nơi thoáng hơn.');
  }
}
