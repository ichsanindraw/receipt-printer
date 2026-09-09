/// A courier the app can quote for.
class Courier {
  const Courier({required this.code, required this.name});

  /// RajaOngkir's courier code — also the key of the offline rate table.
  final String code;

  final String name;

  static const List<Courier> all = [
    Courier(code: 'jne', name: 'JNE'),
    Courier(code: 'jnt', name: 'J&T'),
    Courier(code: 'sicepat', name: 'SiCepat'),
    Courier(code: 'anteraja', name: 'AnterAja'),
    Courier(code: 'pos', name: 'POS'),
    Courier(code: 'tiki', name: 'TIKI'),
    Courier(code: 'ninja', name: 'Ninja'),
    Courier(code: 'lion', name: 'Lion Parcel'),
  ];

  static const List<String> defaultSelection = ['jne', 'jnt', 'sicepat'];

  static String nameFor(String code) => all
      .firstWhere(
        (courier) => courier.code == code,
        orElse: () => Courier(code: code, name: code.toUpperCase()),
      )
      .name;
}
