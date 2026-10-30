import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

void configureBusinessWebCredentials(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}
