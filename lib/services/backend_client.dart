import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException({required this.code, this.message});
  final String code;
  final String? message;
  @override
  String toString() => message ?? code;
}

class DataTimestamp {
  const DataTimestamp(this.seconds, this.nanoseconds);
  factory DataTimestamp.fromDate(DateTime date) {
    final us = date.toUtc().microsecondsSinceEpoch;
    final seconds = (us / 1000000).floor();
    return DataTimestamp(seconds, (us - seconds * 1000000) * 1000);
  }
  final int seconds, nanoseconds;
  DateTime toDate() => DateTime.fromMicrosecondsSinceEpoch(
    seconds * 1000000 + nanoseconds ~/ 1000,
    isUtc: true,
  );
}

class _ServerTime {
  const _ServerTime();
}

class DataValue {
  static Object serverTimestamp() => const _ServerTime();
}

Object? encodeApiData(Object? value) {
  if (value is DataTimestamp) {
    return {r'$date': value.toDate().toIso8601String()};
  }
  if (value is _ServerTime) return {r'$serverTimestamp': true};
  if (value is DateTime) return {r'$date': value.toUtc().toIso8601String()};
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), encodeApiData(v)));
  }
  if (value is Iterable) return value.map(encodeApiData).toList();
  return value;
}

dynamic decodeApiData(dynamic value, [String key = '']) {
  if (value is List) return value.map((v) => decodeApiData(v)).toList();
  if (value is Map) {
    return value.map(
      (k, v) => MapEntry(k.toString(), decodeApiData(v, k.toString())),
    );
  }
  if (value is String && key.endsWith('At')) {
    final date = DateTime.tryParse(value);
    if (date != null) return DataTimestamp.fromDate(date);
  }
  return value;
}

class ApiClient {
  static const baseUrl = String.fromEnvironment('API_BASE_URL');
  static http.Client transport = http.Client();
  static String? testingBaseUrl;
  static String? token;
  static void validateConfiguration() {
    final uri = Uri.tryParse(testingBaseUrl ?? baseUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const ApiException(
        code: 'failed-precondition',
        message:
            'Alamat API belum dikonfigurasi. Isi API_BASE_URL dengan alamat server Railway.',
      );
    }
    if (uri.scheme == 'http' &&
        !(uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host.startsWith('192.168.') ||
            uri.host.startsWith('10.') ||
            RegExp(r'^172\.(1[6-9]|2[0-9]|3[01])\.').hasMatch(uri.host))) {
      throw const ApiException(
        code: 'failed-precondition',
        message: 'Server publik harus menggunakan HTTPS.',
      );
    }
  }

  static Uri _uri(String path, [Map<String, String>? query]) {
    validateConfiguration();
    return Uri.parse(
      '${(testingBaseUrl ?? baseUrl).replaceFirst(RegExp(r'/+$'), '')}$path',
    ).replace(queryParameters: query);
  }

  static Map<String, String> _headers(String? sessionToken) => {
    'Content-Type': 'application/json',
    if (sessionToken != null) 'Authorization': 'Bearer $sessionToken',
  };
  static Future<void> _check(
    http.Response response,
    String? sessionToken,
  ) async {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    Map<String, dynamic> error = {};
    try {
      error = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      /* Non-JSON proxy errors. */
    }
    final code = error['code'] as String? ?? 'http-${response.statusCode}';
    if (code == 'unauthenticated' &&
        sessionToken != null &&
        token == sessionToken) {
      await CargoAuth.instance.clearSession();
    }
    throw ApiException(
      code: code,
      message:
          error['message'] as String? ??
          'Server belum dapat dihubungi (${response.statusCode}). Coba lagi.',
    );
  }

  static Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? data,
    bool get = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      final uri = _uri(path);
      final sessionToken = token;
      final response =
          await (get
                  ? transport.get(uri, headers: _headers(sessionToken))
                  : transport.post(
                      uri,
                      headers: _headers(sessionToken),
                      body: jsonEncode(encodeApiData(data ?? {})),
                    ))
              .timeout(timeout);
      await _check(response, sessionToken);
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } on http.ClientException {
      throw const ApiException(
        code: 'network-request-failed',
        message: 'Server tidak terhubung. Periksa internet dan coba lagi.',
      );
    }
  }

  static Future<Uint8List> photo(String path, int maxBytes) async {
    try {
      final sessionToken = token;
      final response = await transport
          .get(
            _uri('/v1/photos', {'path': path}),
            headers: _headers(sessionToken),
          )
          .timeout(const Duration(seconds: 45));
      await _check(response, sessionToken);
      if (response.bodyBytes.length > maxBytes) {
        throw const ApiException(
          code: 'invalid-argument',
          message: 'Ukuran foto melebihi batas.',
        );
      }
      return response.bodyBytes;
    } on http.ClientException {
      throw const ApiException(
        code: 'network-request-failed',
        message: 'Foto belum dapat diunduh. Periksa internet.',
      );
    }
  }

  static Future<http.StreamedResponse> openTracking(http.Client client) {
    final request = http.Request('GET', _uri('/v1/tracking/stream'));
    request.headers.addAll(_headers(token));
    request.headers['Accept'] = 'text/event-stream';
    return client.send(request).timeout(const Duration(seconds: 15));
  }
}

class CargoUser {
  const CargoUser({required this.uid, required this.email});
  final String uid;
  final String? email;
  factory CargoUser.fromMap(Map<String, dynamic> data) =>
      CargoUser(uid: data['uid'] as String, email: data['email'] as String?);
}

class CargoAuth {
  CargoAuth._();
  static final instance = CargoAuth._();
  final _changes = StreamController<CargoUser?>.broadcast();
  CargoUser? _user;
  CargoUser? get currentUser => _user;
  Future<void> initialize() async {
    ApiClient.validateConfiguration();
    final prefs = await SharedPreferences.getInstance();
    ApiClient.token = prefs.getString('cargo_api_token');
    final saved = prefs.getString('cargo_api_user');
    if (saved != null && ApiClient.token != null) {
      try {
        _user = CargoUser.fromMap(
          Map<String, dynamic>.from(jsonDecode(saved) as Map),
        );
      } catch (_) {
        await clearSession();
      }
    }
  }

  Stream<CargoUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final result = await ApiClient.request(
      '/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    ApiClient.token = result['token'] as String;
    _user = CargoUser.fromMap(Map<String, dynamic>.from(result['user'] as Map));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cargo_api_token', ApiClient.token!);
    await prefs.setString('cargo_api_user', jsonEncode(result['user']));
    _changes.add(_user);
  }

  Future<void> clearSession() async {
    ApiClient.token = null;
    _user = null;
    _changes.add(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cargo_api_token');
    await prefs.remove('cargo_api_user');
  }

  Future<void> signOut() async {
    try {
      if (ApiClient.token != null) {
        await ApiClient.request(
          '/v1/auth/logout',
          timeout: const Duration(seconds: 8),
        );
      }
    } on ApiException catch (e) {
      if (e.code == 'failed-precondition') rethrow;
    } on TimeoutException {
      /* Local sign-out still clears the session. */
    }
    await clearSession();
  }

  Future<void> changePassword(String currentPassword, String password) =>
      ApiClient.request(
        '/v1/auth/change-password',
        data: {'currentPassword': currentPassword, 'password': password},
      ).then((_) {});
}

enum ReadSource { server }

class ReadOptions {
  const ReadOptions({this.source});
  final ReadSource? source;
}

class WriteOptions {
  const WriteOptions({this.merge = false});
  final bool merge;
}

class RecordMetadata {
  const RecordMetadata({this.isFromCache = false});
  final bool isFromCache;
}

class RecordSnapshot<T> {
  RecordSnapshot(
    this.id,
    this._data,
    this.version, {
    this.metadata = const RecordMetadata(),
  });
  final String id;
  final T? _data;
  final String? version;
  final RecordMetadata metadata;
  bool get exists => _data != null;
  T? data() => _data;
  RecordSnapshot<T> cached() => RecordSnapshot(
    id,
    _data,
    version,
    metadata: const RecordMetadata(isFromCache: true),
  );
}

class RecordDocument<T> extends RecordSnapshot<T> {
  RecordDocument(super.id, T super.data, super.version, {super.metadata});
  @override
  T data() => super.data() as T;
}

class RecordSet<T> {
  RecordSet(this.docs, {this.metadata = const RecordMetadata()});
  final List<RecordDocument<T>> docs;
  final RecordMetadata metadata;
  bool get empty => docs.isEmpty;
  int get size => docs.length;
  RecordSet<T> cached() =>
      RecordSet(docs, metadata: const RecordMetadata(isFromCache: true));
}

Stream<T> _watch<T>(Future<T> Function() load, T Function(T) cached) {
  late StreamController<T> controller;
  Timer? timer;
  bool closed = false, busy = false;
  T? last;
  Future<void> refresh() async {
    if (closed || busy) return;
    busy = true;
    try {
      final next = await load();
      if (!closed) {
        last = next;
        controller.add(next);
      }
    } catch (e, stack) {
      if (!closed) {
        if (last != null) {
          controller.add(cached(last as T));
        } else {
          controller.addError(e, stack);
        }
      }
    } finally {
      busy = false;
    }
  }

  controller = StreamController<T>(
    onListen: () {
      refresh();
      timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    },
    onCancel: () {
      closed = true;
      timer?.cancel();
    },
  );
  return controller.stream;
}

String _id() {
  final random = Random.secure();
  return base64UrlEncode(List.generate(15, (_) => random.nextInt(256)));
}

class CargoStore {
  CargoStore._();
  static final instance = CargoStore._();
  RecordCollection<Map<String, dynamic>> collection(String path) =>
      RecordCollection(path);
  Future<T> runTransaction<T>(Future<T> Function(CargoTransaction) work) async {
    for (var attempt = 0; ; attempt++) {
      final tx = CargoTransaction();
      final value = await work(tx);
      try {
        await ApiClient.request(
          '/v1/transactions',
          data: {'reads': tx.reads, 'writes': tx.writes},
        );
        return value;
      } on ApiException catch (e) {
        if (e.code != 'conflict' || attempt >= 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 100 * (attempt + 1)));
      }
    }
  }
}

class RecordQuery<T> {
  RecordQuery(
    this.path, {
    this.filters = const [],
    this.order = const [],
    this.count = 50,
  });
  final String path;
  final List<List<dynamic>> filters, order;
  final int count;
  RecordQuery<T> where(
    String field, {
    Object? isEqualTo,
    Object? isGreaterThanOrEqualTo,
    Object? isLessThan,
  }) {
    final op = isGreaterThanOrEqualTo != null
        ? 'gte'
        : isLessThan != null
        ? 'lt'
        : 'eq';
    final value = isGreaterThanOrEqualTo ?? isLessThan ?? isEqualTo;
    return RecordQuery(
      path,
      filters: [
        ...filters,
        [field, op, value],
      ],
      order: order,
      count: count,
    );
  }

  RecordQuery<T> orderBy(String field, {bool descending = false}) =>
      RecordQuery(
        path,
        filters: filters,
        order: [
          ...order,
          [field, descending],
        ],
        count: count,
      );
  RecordQuery<T> limit(int value) =>
      RecordQuery(path, filters: filters, order: order, count: value);
  Future<RecordSet<T>> get([ReadOptions? options]) async {
    final result = await ApiClient.request(
      '/v1/query',
      data: {'path': path, 'filters': filters, 'order': order, 'limit': count},
    );
    return RecordSet(
      (result['docs'] as List).map((dynamic raw) {
        final d = Map<String, dynamic>.from(raw as Map);
        return RecordDocument<T>(
          d['id'] as String,
          decodeApiData(d['data']) as T,
          d['version'] as String?,
        );
      }).toList(),
    );
  }

  Stream<RecordSet<T>> snapshots({bool includeMetadataChanges = false}) =>
      _watch(() => get(), (s) => s.cached());
}

class RecordCollection<T> extends RecordQuery<T> {
  RecordCollection(super.path);
  RecordReference<T> doc([String? id]) =>
      RecordReference('$path/${id ?? _id()}');
}

class RecordReference<T> {
  RecordReference(this.path);
  final String path;
  String get id => path.split('/').last;
  RecordCollection<Map<String, dynamic>> collection(String name) =>
      RecordCollection('$path/$name');
  Future<RecordSnapshot<T>> get([ReadOptions? options]) async {
    final raw = (await ApiClient.request(
      '/v1/record',
      data: {'path': path},
    ))['doc'];
    if (raw == null) return RecordSnapshot(id, null, null);
    final result = Map<String, dynamic>.from(raw as Map);
    return RecordSnapshot(
      id,
      decodeApiData(result['data']) as T,
      result['version'] as String?,
    );
  }

  Stream<RecordSnapshot<T>> snapshots({bool includeMetadataChanges = false}) =>
      _watch(() => get(), (s) => s.cached());
  Future<void> set(
    Map<String, dynamic> data, [
    WriteOptions options = const WriteOptions(),
  ]) => ApiClient.request(
    '/v1/transactions',
    data: {
      'reads': [],
      'writes': [
        {'path': path, 'kind': 'set', 'merge': options.merge, 'data': data},
      ],
    },
  ).then((_) {});
  Future<void> update(Map<String, dynamic> data) => ApiClient.request(
    '/v1/transactions',
    data: {
      'reads': [],
      'writes': [
        {'path': path, 'kind': 'update', 'data': data},
      ],
    },
  ).then((_) {});
}

class CargoTransaction {
  final reads = <Map<String, dynamic>>[], writes = <Map<String, dynamic>>[];
  Future<RecordSnapshot<T>> get<T>(RecordReference<T> ref) async {
    final result = await ref.get();
    reads.add({'path': ref.path, 'version': result.version});
    return result;
  }

  void set<T>(RecordReference<T> ref, Map<String, dynamic> data) =>
      writes.add({'path': ref.path, 'kind': 'set', 'data': data});
  void update<T>(RecordReference<T> ref, Map<String, dynamic> data) =>
      writes.add({'path': ref.path, 'kind': 'update', 'data': data});
}

class CargoActions {
  CargoActions._();
  static final instance = CargoActions._();
  CargoAction httpsCallable(String name) => CargoAction(name);
}

class CargoAction {
  CargoAction(this.name);
  final String name;
  Future<Map<String, dynamic>> call(Map<String, dynamic> data) =>
      ApiClient.request('/v1/actions/$name', data: data);
}

class UploadMetadata {
  const UploadMetadata({required this.contentType});
  final String contentType;
}

class CargoFiles {
  CargoFiles._();
  static final instance = CargoFiles._();
  CargoFile ref(String path) => CargoFile(path);
}

class CargoFile {
  CargoFile(this.path);
  final String path;
  Future<Uint8List?> getData(int maxBytes) => ApiClient.photo(path, maxBytes);
  Future<void> putData(Uint8List bytes, UploadMetadata metadata) =>
      ApiClient.request(
        '/v1/photos/upload',
        data: {
          'path': path,
          'contentType': metadata.contentType,
          'base64': base64Encode(bytes),
        },
        timeout: const Duration(seconds: 60),
      ).then((_) {});
}
