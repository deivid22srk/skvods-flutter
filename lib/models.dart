class Video {
  final String id;
  final String title;
  final String user;
  final String? poster;
  final String? tag;
  final int? dateEpoch;
  final String? type;
  final String? description;
  final int? views;
  final int duration;
  final String? animated;
  final String? userDisplayName;
  final String? userImage;
  final Map<String, ImdbTimestamp>? imdb;
  final Map<String, ImdbTitleData>? imdbData;

  Video({
    required this.id,
    required this.title,
    required this.user,
    this.poster,
    this.tag,
    this.dateEpoch,
    this.type,
    this.description,
    this.views,
    required this.duration,
    this.animated,
    this.userDisplayName,
    this.userImage,
    this.imdb,
    this.imdbData,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    // Parse IMDb Timestamps
    Map<String, ImdbTimestamp>? imdbMap;
    if (json['imdb'] != null && json['imdb'] is Map) {
      imdbMap = {};
      (json['imdb'] as Map).forEach((key, value) {
        if (value is Map) {
          imdbMap![key.toString()] = ImdbTimestamp.fromJson(Map<String, dynamic>.from(value));
        }
      });
    }

    // Parse IMDb Data
    Map<String, ImdbTitleData>? imdbDataMap;
    if (json['imdb_data'] != null && json['imdb_data'] is Map) {
      imdbDataMap = {};
      (json['imdb_data'] as Map).forEach((key, value) {
        if (value is Map) {
          imdbDataMap![key.toString()] = ImdbTitleData.fromJson(Map<String, dynamic>.from(value));
        }
      });
    }

    return Video(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      user: json['user']?.toString() ?? '',
      poster: json['poster'],
      tag: json['tag'],
      dateEpoch: json['date_epoch'] != null ? int.tryParse(json['date_epoch'].toString()) : null,
      type: json['type'],
      description: json['description'],
      views: json['views'] != null ? int.tryParse(json['views'].toString()) : null,
      duration: json['duration'] != null ? int.parse(json['duration'].toString()) : 0,
      animated: json['animated'],
      userDisplayName: json['user_display_name'],
      userImage: json['user_image'],
      imdb: imdbMap,
      imdbData: imdbDataMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'user': user,
      'poster': poster,
      'tag': tag,
      'date_epoch': dateEpoch,
      'type': type,
      'description': description,
      'views': views,
      'duration': duration,
      'animated': animated,
      'user_display_name': userDisplayName,
      'user_image': userImage,
    };
  }
}

class ImdbTimestamp {
  final int timestamp;
  final String? tag;

  ImdbTimestamp({required this.timestamp, this.tag});

  factory ImdbTimestamp.fromJson(Map<String, dynamic> json) {
    return ImdbTimestamp(
      timestamp: json['timestamp'] != null ? int.parse(json['timestamp'].toString()) : 0,
      tag: json['tag'],
    );
  }
}

class ImdbTitleData {
  final String? primaryTitle;
  final String? brTitle;
  final String? posterUrl;
  final double? averageRating;
  final int? voteCount;
  final int? startYear;
  final int? runtimeSeconds;
  final List<String>? genres;
  final String? plot;

  ImdbTitleData({
    this.primaryTitle,
    this.brTitle,
    this.posterUrl,
    this.averageRating,
    this.voteCount,
    this.startYear,
    this.runtimeSeconds,
    this.genres,
    this.plot,
  });

  factory ImdbTitleData.fromJson(Map<String, dynamic> json) {
    List<String>? parsedGenres;
    if (json['genres'] != null) {
      parsedGenres = List<String>.from(json['genres']);
    }

    String? poster;
    if (json['primaryImage'] != null && json['primaryImage'] is Map) {
      poster = json['primaryImage']['url'];
    }

    return ImdbTitleData(
      primaryTitle: json['primaryTitle'],
      brTitle: json['brTitle'],
      posterUrl: poster,
      averageRating: json['averageRating'] != null ? double.tryParse(json['averageRating'].toString()) : null,
      voteCount: json['voteCount'] != null ? int.tryParse(json['voteCount'].toString()) : null,
      startYear: json['startYear'] != null ? int.tryParse(json['startYear'].toString()) : null,
      runtimeSeconds: json['runtimeSeconds'] != null ? int.tryParse(json['runtimeSeconds'].toString()) : null,
      genres: parsedGenres,
      plot: json['plot'],
    );
  }
}

class Streamer {
  final String id;
  final String name;
  final String image;
  final Map<String, String>? socials;

  Streamer({
    required this.id,
    required this.name,
    required this.image,
    this.socials,
  });

  factory Streamer.fromJson(Map<String, dynamic> json) {
    Map<String, String>? socialsMap;
    if (json['socials'] != null && json['socials'] is Map) {
      socialsMap = {};
      (json['socials'] as Map).forEach((key, value) {
        socialsMap![key.toString()] = value.toString();
      });
    }

    return Streamer(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      socials: socialsMap,
    );
  }
}

class Tag {
  final String slug;
  final String name;
  final String? imdbId;
  final int? season;
  final int? videoCount;
  final List<String>? users;

  Tag({
    required this.slug,
    required this.name,
    this.imdbId,
    this.season,
    this.videoCount,
    this.users,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    List<String>? usersList;
    if (json['users'] != null) {
      usersList = List<String>.from(json['users'].map((x) => x.toString()));
    }

    return Tag(
      slug: json['slug'] ?? '',
      name: json['name'] ?? '',
      imdbId: json['imdb_id']?.toString(),
      season: json['season'] != null ? int.tryParse(json['season'].toString()) : null,
      videoCount: json['video_count'] != null ? int.tryParse(json['video_count'].toString()) : null,
      users: usersList,
    );
  }
}

class StreamSource {
  final String type;
  final String quality;
  final bool isLivestream;
  final bool isLocal;
  final String url;

  StreamSource({
    required this.type,
    required this.quality,
    required this.isLivestream,
    required this.isLocal,
    required this.url,
  });

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    return StreamSource(
      type: json['type'] ?? '',
      quality: json['quality'] ?? '',
      isLivestream: json['isLivestream'] ?? false,
      isLocal: json['isLocal'] ?? false,
      url: json['url'] ?? '',
    );
  }
}

class LiveChannel {
  final String name;
  final String title;
  final String url;

  LiveChannel({
    required this.name,
    required this.title,
    required this.url,
  });

  factory LiveChannel.fromJson(Map<String, dynamic> json) {
    return LiveChannel(
      name: json['name'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
    );
  }
}

class InternetArchiveFile {
  final String name;
  final String size;
  final String format;
  final String length;

  InternetArchiveFile({
    required this.name,
    required this.size,
    required this.format,
    required this.length,
  });

  factory InternetArchiveFile.fromJson(Map<String, dynamic> json) {
    return InternetArchiveFile(
      name: json['name'] ?? '',
      size: json['size'] ?? '0',
      format: json['format'] ?? '',
      length: json['length'] ?? '0',
    );
  }
}
