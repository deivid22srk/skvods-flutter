import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  static const String baseUrl = 'https://skvods.lol';
  static const String cdnBaseUrl = 'https://cdn2.skvods.lol';

  // Standard headers to bypass hotlinking protection
  static const Map<String, String> headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
    'Referer': 'https://skvods.lol/',
  };

  // 1. Fetch all streamers
  static Future<List<Streamer>> fetchStreamers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/users'), headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Streamer.fromJson(json)).toList();
      }
      throw Exception('Código de status do servidor: ${response.statusCode}');
    } catch (e) {
      print('Erro ao buscar streamers: $e');
      rethrow;
    }
  }

  // 2. Fetch tags (series / seasons)
  static Future<List<Tag>> fetchTags() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/tags?marked=true'), headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Tag.fromJson(json)).toList();
      }
      throw Exception('Código de status do servidor: ${response.statusCode}');
    } catch (e) {
      print('Erro ao buscar tags: $e');
      rethrow;
    }
  }

  // 3. Fetch list of videos (paginated / filtered)
  static Future<Map<String, dynamic>> fetchVideos({
    int page = 1,
    int limit = 12,
    String? tag,
    String? user,
    String? sort,
    String? search,
  }) async {
    try {
      String urlString;
      if (search != null && search.isNotEmpty) {
        urlString = '$baseUrl/api/search?term=${Uri.encodeComponent(search)}&limit=30';
      } else if (tag != null && tag.isNotEmpty) {
        urlString = '$baseUrl/api/list?tag=$tag&limit=100';
      } else if (user != null && user.isNotEmpty) {
        urlString = '$baseUrl/api/list?user=$user&limit=$limit&page=$page';
      } else {
        urlString = '$baseUrl/api/list?limit=$limit&page=$page';
      }

      if (sort == 'views') {
        urlString += '&views=top';
      }

      final response = await http.get(Uri.parse(urlString), headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        List<Video> videos = [];
        int totalItems = 0;

        if (data['videos'] != null) {
          final List<dynamic> list = data['videos'];
          videos = list.map((json) => Video.fromJson(json)).toList();
          totalItems = data['total_items'] != null ? int.parse(data['total_items'].toString()) : videos.length;
        } else if (data['results'] != null) {
          final List<dynamic> list = data['results'];
          videos = list.map((json) => Video.fromJson(json)).toList();
          totalItems = videos.length;
        } else if (data['total_items'] != null) {
          // Alternative structure where it maps array directly
          final List<dynamic> list = data['videos'] ?? [];
          videos = list.map((json) => Video.fromJson(json)).toList();
          totalItems = int.parse(data['total_items'].toString());
        } else {
          // If it returns list directly as response (sometimes search results do)
          final dynamic decoded = json.decode(response.body);
          if (decoded is List) {
            videos = decoded.map((json) => Video.fromJson(json)).toList();
            totalItems = videos.length;
          }
        }

        return {
          'videos': videos,
          'totalItems': totalItems,
        };
      }
      throw Exception('Código de status do servidor: ${response.statusCode}');
    } catch (e) {
      print('Erro ao buscar vídeos: $e');
      rethrow;
    }
  }

  // 4. Fetch stream details (mp4 / hls links)
  static Future<List<StreamSource>> fetchStreamSources(String videoId) async {
    try {
      final response = await http.get(Uri.parse('$cdnBaseUrl/test_streams/$videoId'), headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['available_streams'] != null) {
          final List<dynamic> list = data['available_streams'];
          return list.map((json) => StreamSource.fromJson(json)).toList();
        }
        return [];
      }
      throw Exception('Código de status do servidor: ${response.statusCode}');
    } catch (e) {
      print('Erro ao buscar fontes do stream para $videoId: $e');
      rethrow;
    }
  }

  // 5. Fetch Internet Archive details
  static Future<List<InternetArchiveFile>> fetchInternetArchiveFiles(String videoId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/fetch_ia_files?id=$videoId'), headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['result'] != null) {
          final List<dynamic> list = data['result'];
          return list.map((json) => InternetArchiveFile.fromJson(json)).toList();
        }
        return [];
      }
      return [];
    } catch (e) {
      print('Erro ao buscar arquivos do IA para $videoId: $e');
      return [];
    }
  }

  // 6. Fetch currently active live channels
  static Future<List<LiveChannel>> fetchLiveChannels() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/data/now_live.json'), headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['channels'] != null) {
          final List<dynamic> list = data['channels'];
          return list.map((json) => LiveChannel.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Erro ao buscar canais ao vivo: $e');
      return [];
    }
  }
}
