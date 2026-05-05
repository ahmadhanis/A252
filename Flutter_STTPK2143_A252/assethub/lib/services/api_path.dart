import 'package:flutter/foundation.dart';

class ApiPath {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost/assethub/api";
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return "http://10.0.2.2/assethub/api";
      default:
        return "http://localhost/assethub/api";
    }
  }

  static String endpoint(String fileName) {
    return "$baseUrl/$fileName";
  }
}
