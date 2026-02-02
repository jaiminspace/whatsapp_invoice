import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../domain/business_profile.dart';

final businessProfileProvider =
NotifierProvider<BusinessProfileNotifier, BusinessProfile>(
  BusinessProfileNotifier.new,
);

class BusinessProfileNotifier extends Notifier<BusinessProfile> {
  late final Box settingsBox;

  static const _key = 'business_profile';

  @override
  BusinessProfile build() {
    settingsBox = Hive.box('settings');
    final raw = settingsBox.get(_key);
    return BusinessProfile.fromJson(raw is Map ? raw : null);
  }

  Future<void> save(BusinessProfile profile) async {
    await settingsBox.put(_key, profile.toJson());
    state = profile;
  }
}
