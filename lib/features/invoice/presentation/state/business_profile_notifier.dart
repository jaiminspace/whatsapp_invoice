import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../domain/business_profile.dart';

final businessProfileProvider =
NotifierProvider<BusinessProfileNotifier, BusinessProfile>(
  BusinessProfileNotifier.new,
);

class BusinessProfileNotifier extends Notifier<BusinessProfile> {
  late final Box _box;

  @override
  BusinessProfile build() {
    _box = Hive.box('settings');
    final raw = _box.get('business_profile');

    if (raw is Map) {
      return BusinessProfile.fromJson(raw);
    }
    return BusinessProfile.initial();
  }

  Future<void> save(BusinessProfile profile) async {
    state = profile;
    await _box.put('business_profile', profile.toJson());
  }
}
