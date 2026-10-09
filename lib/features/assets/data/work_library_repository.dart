import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_api.dart';
import '../domain/library_work.dart';

class WorkLibraryRepository {
  const WorkLibraryRepository(this._api);

  final NetworkApi _api;

  Future<LibraryWorkPage> fetchPage({
    required int type,
    required int page,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      return LibraryWorkPage.fromJson(
        await _api.listLibraryWorks(
          type: type,
          page: page,
          pageSize: pageSize,
          cancelToken: cancelToken,
        ),
        page: page,
        pageSize: pageSize,
        mediaBaseUrl: _api.mediaBaseUrl,
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<void> delete(String id, {CancelToken? cancelToken}) async {
    try {
      await _api.deleteLibraryWork(id, cancelToken: cancelToken);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}
