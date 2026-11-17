import 'draft_store_web.dart'
    if (dart.library.io) 'draft_store_io.dart'
    as platform;
export 'draft_types.dart';

final deliveryDraftStore = platform.createDraftStore();
