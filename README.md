# Receipt Printer

A small cross-platform Flutter app for Indonesian delivery work, in two tabs:

- **Resi** — fill in sender, recipient, receipt number, product, phone and a
  map-backed address, then print an 80 mm receipt through the device's native
  print dialog.
- **Ongkir** — compare courier tariffs between two places by weight.

One codebase, running on **Android, iOS and the web**.

## Resi

| | |
|---|---|
| **Nomor resi** | Auto-generated as `RCP-yyyyMMdd-HHmm`, editable, regenerate button |
| **Dari / Kepada** | Sender and recipient names |
| **Telepon** | Recipient phone, validated |
| **Nama produk** | What is being delivered |
| **Alamat** | Type-ahead autocomplete backed by a real geocoder |
| **Peta** | The picked address is pinned on OpenStreetMap; tap the map to move the pin and the address is reverse-geocoded to match |
| **Cetak resi** | Renders an 80 mm receipt PDF and opens the system print dialog |
| **Pratinjau** | Full-screen preview with print and share actions |

The printed receipt carries a QR code linking to the delivery address on Google
Maps, so a courier can scan the paper slip and navigate straight there.

## Ongkir

Pick an origin and destination, set the weight, choose couriers, and get every
service sorted cheapest first with its delivery estimate.

Every Indonesian rate API needs an account and a key, so the app has two
providers behind one `ShippingRateService` interface:

**Offline estimator — the default, no key, no setup.**

It reuses the coordinates the map geocoder already produces and prices the
great-circle distance against a per-courier tariff table. The table is
calibrated against live reguler quotes (Jakarta–Bandung ≈ Rp 11–12k,
Jakarta–Surabaya ≈ Rp 24k, Jakarta–Makassar ≈ Rp 40k), but couriers really
price by zone, so these are **estimates** — good enough to sanity-check a
delivery, not to bill a customer. The UI labels them as such.

**RajaOngkir V2 (Komerce) — real tariffs.**

```bash
flutter run --dart-define=RAJAONGKIR_API_KEY=your_key_here
```

With a key, origin and destination autocomplete against RajaOngkir's own
kecamatan-level database (the cost endpoint addresses places by their
RajaOngkir id) and the quotes come straight from the couriers.

> **Never commit an API key.** Keys go in `dart_defines.json`, which is
> gitignored — copy `dart_defines.example.json` and fill it in, then run:
>
> ```bash
> flutter run --dart-define-from-file=dart_defines.json
> ```

## Address autocomplete

Same pattern, two providers:

- **OpenStreetMap Nominatim** — the default, no API key.
- **Google Places** — used automatically when you supply a key:

```bash
flutter run --dart-define=GOOGLE_PLACES_API_KEY=your_key_here
```

Enable both *Places API (New)* and *Geocoding API* for that key — the first
powers autocomplete and place details, the second powers reverse geocoding when
the user taps the map. The active provider is shown as a chip on the card.

> Nominatim asks for at most one request per second per client. Keystrokes are
> debounced by 450 ms and every request is superseded by the next one, which
> keeps usage well inside that limit for interactive typing. For production
> traffic, use Google Places or host your own Nominatim instance.

## Running it

```bash
flutter pub get
flutter run
```

Targets: Android, iOS, and web (`flutter run -d chrome`). Printing uses the
platform's own print service — AirPrint on iOS, the Android print framework,
and the browser print dialog on web.

```bash
flutter test
```

## Design

The UI deliberately avoids stock Material so it does not read as an Android
template on either platform:

- **Plus Jakarta Sans** (bundled, OFL) — an Indonesian typeface, tight tracking
  on headings, small-caps section labels.
- Warm paper neutrals with ink-black primary actions and a single amber accent,
  rather than a tinted Material colour scheme. Light and dark both defined.
- Custom components instead of the Material defaults they replace:
  `AppTextField` puts the label above the box (no notched outline),
  `SegmentedTabs` is a sliding pill (no `TabBar` underline or `NavigationBar`),
  `AppButton` and `AppChoiceChip` drop the ripple for a press-scale.
- Tokens live in `lib/theme/app_theme.dart`; extra colours the Material
  `ColorScheme` has no slot for hang off an `AppPalette` theme extension.

## How it is put together

```
lib/
├── config/app_config.dart              build-time config (API keys, user agent)
├── theme/app_theme.dart                colours, type scale, shapes
├── models/
│   ├── address_suggestion.dart         one place: label, id, coordinates
│   ├── receipt.dart                    the form's data, plus the maps deep link
│   ├── courier.dart                    courier codes and names
│   └── shipping_quote.dart             one quoted service
├── services/
│   ├── address_service.dart            geocoder interface
│   ├── nominatim_address_service.dart  OpenStreetMap implementation
│   ├── google_places_address_service.dart
│   ├── shipping_rate_service.dart      rate-provider interface
│   ├── estimated_shipping_rate_service.dart   offline distance model
│   ├── rajaongkir_shipping_rate_service.dart  live tariffs
│   ├── *_factory.dart                  pick a provider from the build config
│   └── receipt_pdf_service.dart        renders the 80 mm receipt PDF
├── screens/
│   ├── home_screen.dart                tab shell, owns the shared services
│   ├── receipt_form_screen.dart        Resi tab
│   ├── shipping_screen.dart            Ongkir tab
│   └── receipt_preview_screen.dart     PDF preview with print/share
└── widgets/                            the design-system components
```

Swapping in another geocoder or rate provider means implementing
`AddressService` or `ShippingRateService` and returning it from the matching
factory — nothing else in the app knows which provider is in use.

## Notes

- The receipt PDF uses `PdfPageFormat.roll80` with an unbounded height, so the
  paper grows with the content. On a thermal receipt printer it fills the roll;
  sent to an A4 printer it lands as an 80 mm-wide strip, which is the intended
  shape.
- The PDF uses the built-in Courier fonts, which cover Latin-1. If you need
  non-Latin scripts on the receipt, bundle a Unicode TTF and pass it to
  `ReceiptPdfService`.
- Map tiles come from OpenStreetMap's public tile servers. Their tile usage
  policy applies; for real traffic, point `MapPreview` at your own tile source.
- Shipping quotes exclude volume weight and insurance.

## License

MIT — see [LICENSE](LICENSE). Plus Jakarta Sans is licensed under the SIL Open
Font License; see [assets/fonts/OFL.txt](assets/fonts/OFL.txt).
