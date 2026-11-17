import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_client.dart';

/// Authenticated server push with reconnection and a REST recovery snapshot.
/// Owns its HTTP client so leaving the map closes the streaming connection.
Stream<RecordSet<Map<String, dynamic>>> watchCourierLocations({
  http.Client Function()? clientFactory,
}) {
  late StreamController<RecordSet<Map<String, dynamic>>> controller;
  http.Client? client;
  StreamSubscription<String>? subscription;
  Timer? reconnect, watchdog;
  RecordSet<Map<String, dynamic>>? last;
  final session = ApiClient.token;
  bool closed = false, recovering = false;
  int attempts = 0;

  void emit(RecordSet<Map<String, dynamic>> value) {
    if (!closed && ApiClient.token == session) {
      last = value;
      controller.add(value);
    }
  }

  Future<void> connect() async {
    if (closed || ApiClient.token != session) return;
    recovering = false;
    final connection = (clientFactory ?? http.Client.new)();
    client = connection;

    Future<void> recover(Object error) async {
      if (closed || recovering) return;
      recovering = true;
      watchdog?.cancel();
      await subscription?.cancel();
      connection.close();
      if (closed || ApiClient.token != session) return;
      if (last != null) controller.add(last!.cached());
      try {
        emit(
          await CargoStore.instance
              .collection('courier_locations')
              .limit(5000)
              .get(),
        );
      } catch (_) {
        if (!closed && last == null) controller.addError(error);
      }
      if (closed || ApiClient.token != session) return;
      attempts = (attempts + 1).clamp(1, 4);
      reconnect = Timer(Duration(seconds: 1 << attempts), connect);
    }

    try {
      final response = await ApiClient.openTracking(connection);
      if (closed || ApiClient.token != session) {
        connection.close();
        return;
      }
      if (response.statusCode != 200) {
        if (response.statusCode == 401 && ApiClient.token == session) {
          await CargoAuth.instance.clearSession();
        }
        throw ApiException(
          code: 'tracking-unavailable',
          message: 'Sambungan lokasi belum tersedia.',
        );
      }
      void touch() {
        watchdog?.cancel();
        watchdog = Timer(
          const Duration(seconds: 40),
          () => recover(TimeoutException('Koneksi lokasi terputus')),
        );
      }

      touch();
      subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              touch();
              if (line == 'event: expired') {
                if (ApiClient.token == session) {
                  CargoAuth.instance.clearSession();
                }
                connection.close();
                return;
              }
              if (!line.startsWith('data: ')) return;
              try {
                final data = jsonDecode(line.substring(6)) as Map;
                if (data['docs'] is! List) {
                  if (last != null && !closed) controller.add(last!.cached());
                  return;
                }
                attempts = 0;
                emit(
                  RecordSet(
                    (data['docs'] as List).map((dynamic value) {
                      final row = Map<String, dynamic>.from(value as Map);
                      return RecordDocument<Map<String, dynamic>>(
                        row['id'] as String,
                        Map<String, dynamic>.from(
                          decodeApiData(row['data']) as Map,
                        ),
                        row['version'] as String?,
                      );
                    }).toList(),
                  ),
                );
              } catch (error) {
                recover(error);
              }
            },
            onError: recover,
            onDone: () => recover(StateError('Sambungan lokasi berakhir')),
            cancelOnError: true,
          );
    } catch (error) {
      await recover(error);
    }
  }

  controller = StreamController<RecordSet<Map<String, dynamic>>>(
    onListen: connect,
    onCancel: () async {
      closed = true;
      reconnect?.cancel();
      watchdog?.cancel();
      client?.close();
      await subscription?.cancel();
    },
  );
  return controller.stream;
}
