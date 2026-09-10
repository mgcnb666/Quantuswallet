import 'package:quantus_sdk/src/services/settings_service.dart';

class AddressBookService {
  static final AddressBookService _instance = AddressBookService._internal();
  factory AddressBookService() => _instance;
  AddressBookService._internal();

  final SettingsService _settingsService = SettingsService();

  Future<void> setAddressName(String address, String name) async {
    await _settingsService.setAddressName(address, name);
  }

  Future<String?> getAddressName(String address) async {
    return await _settingsService.getAddressName(address);
  }

  Future<void> removeAddressName(String address) async {
    await _settingsService.removeAddressName(address);
  }

  Future<Map<String, String>> getAddressBook() async {
    return await _settingsService.getAddressBook();
  }
}
