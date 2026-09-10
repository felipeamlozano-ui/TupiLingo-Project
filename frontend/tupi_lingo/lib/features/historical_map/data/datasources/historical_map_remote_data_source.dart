import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tupi_lingo/core/network/api_client.dart';
import '../models/historical_region_model.dart';

abstract class HistoricalMapRemoteDataSource {
  Future<List<HistoricalRegionModel>> fetchRegions();
  Future<HistoricalRegionModel> createRegion(HistoricalRegionModel region);
  Future<HistoricalRegionModel> updateRegion(HistoricalRegionModel region);
  Future<bool> deleteRegion(int regionId);
}

class HistoricalMapRemoteDataSourceImpl implements HistoricalMapRemoteDataSource {
  String get _baseUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';

  @override
  Future<List<HistoricalRegionModel>> fetchRegions() async {
    try {
      final res = await ApiClient.get('$_baseUrl/api/v1/trilha/regioes/');
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        final list = (data['regioes'] as List<dynamic>? ?? []).map((e) {
          return HistoricalRegionModel.fromJson(e as Map<String, dynamic>);
        }).toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return HistoricalRegionModel.defaultHistoricalRegions();
  }

  @override
  Future<HistoricalRegionModel> createRegion(HistoricalRegionModel region) async {
    try {
      final res = await ApiClient.post(
        '$_baseUrl/api/v1/admin/trilha/regioes/',
        body: region.toJson(),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        return HistoricalRegionModel.fromJson(data['regiao'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return region;
  }

  @override
  Future<HistoricalRegionModel> updateRegion(HistoricalRegionModel region) async {
    try {
      final res = await ApiClient.put(
        '$_baseUrl/api/v1/admin/trilha/regioes/${region.id}/',
        body: region.toJson(),
      );
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        return HistoricalRegionModel.fromJson(data['regiao'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return region;
  }

  @override
  Future<bool> deleteRegion(int regionId) async {
    try {
      final res = await ApiClient.delete(
        '$_baseUrl/api/v1/admin/trilha/regioes/$regionId/',
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {}
    return true;
  }
}
