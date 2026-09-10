import 'package:flutter/foundation.dart';

@immutable
class OAuthLink {
  final String url;

  const OAuthLink({required this.url});

  factory OAuthLink.fromJson(Map<String, dynamic> json) {
    return OAuthLink(url: json['url'] as String);
  }
}
