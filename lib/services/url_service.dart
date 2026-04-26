import 'package:url_launcher/url_launcher.dart';

class UrlService {
  static const _supportedBrowsers = [
    'com.android.chrome',
    'com.android.browser',
    'org.mozilla.firefox',
    'com.sec.android.app.sbrowser',
    'com.google.android.apps.chrome',
  ];

  Future<bool> openUrl(String url, {String? browserPackage}) async {
    String finalUrl = url;
    
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }

    final uri = Uri.parse(finalUrl);

    if (browserPackage != null) {
      try {
        final intent = await _launchViaIntent(uri, browserPackage);
        if (intent) return true;
      } catch (e) {
        // Fall through to default
      }
    }

    return _launchWithDefault(uri);
  }

  Future<bool> _launchViaIntent(Uri uri, String package) async {
    try {
      final result = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return result;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _launchWithDefault(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    final fallbackUri = Uri.parse('https://www.google.com/search?q=${uri.host}');
    if (await canLaunchUrl(fallbackUri)) {
      return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
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
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
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
    final queryParams = body != null ? {'body': body} : null;
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
    final queryParams = label != null ? {'q': label} : null;
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