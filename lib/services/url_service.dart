import 'package:url_launcher/url_launcher.dart';

class UrlService {
  Future<bool> openUrl(String url) async {
    String finalUrl = url;
    
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }

    final uri = Uri.parse(finalUrl);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    return false;
  }

  Future<bool> openInBrowser(String url) async {
    return openUrl(url);
  }

  Future<bool> openInIncognito(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      return false;
    }
  }

  Future<bool> openMail({
    required String to,
    String? subject,
    String? body,
  }) async {
    final queryParams = <String, String>{};
    if (subject != null) queryParams['subject'] = subject;
    if (body != null) queryParams['body'] = body;
    
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  Future<void> makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> sendSms(String phoneNumber, {String? body}) async {
    final queryParams = body != null ? <String, String>{'body': body} : null;
    final uri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: queryParams,
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> openMap(double lat, double lng, {String? label}) async {
    final queryParams = label != null ? <String, String>{'q': label} : null;
    final uri = Uri(
      scheme: 'geo',
      host: '$lat,$lng',
      queryParameters: queryParams,
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      await openUrl(mapUrl);
    }
  }

  Future<bool> canOpenUrl(String url) async {
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }
    final uri = Uri.parse(finalUrl);
    return canLaunchUrl(uri);
  }

  Future<List<Map<String, String>>> getInstalledBrowsers() async {
    final browsers = <Map<String, String>>[];
    
    final defaultCanLaunch = await canLaunchUrl(Uri.parse('https://www.google.com'));
    if (defaultCanLaunch) {
      browsers.add({'package': 'default', 'name': 'Default'});
    }

    return browsers;
  }

  String getBrowserName(String package) {
    final names = {
      'default': 'Default Browser',
      'com.android.chrome': 'Google Chrome',
      'com.android.browser': 'Browser',
      'org.mozilla.firefox': 'Firefox',
      'com.sec.android.app.sbrowser': 'Samsung Internet',
      'com.google.android.apps.chrome': 'Chrome',
    };
    return names[package] ?? 'Browser';
  }
}

class UrlParser {
  static Map<String, dynamic>? parseUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return {
        'scheme': uri.scheme,
        'host': uri.host,
        'port': uri.port,
        'path': uri.path,
        'query': uri.queryParameters,
        'fragment': uri.fragment,
        'isSecure': uri.isScheme('https'),
      };
    } catch (e) {
      return null;
    }
  }

  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  static String extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return '';
    }
  }

  static String? extractParameter(String url, String key) {
    try {
      final uri = Uri.parse(url);
      return uri.queryParameters[key];
    } catch (e) {
      return null;
    }
  }
}