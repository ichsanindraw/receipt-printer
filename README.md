# Receipt Printer

A small cross-platform Flutter app that collects delivery details — sender, recipient,
receipt number, product, phone, and a map-backed address — and prints a proper
80 mm receipt through the device's native print dialog.

Built with Flutter, so one codebase runs on **Android, iOS and the web**.

## What it does

| | |
|---|---|
| **Receipt number** | Auto-generated as `RCP-yyyyMMdd-HHmm`, editable, regenerate button |
| **From / To** | Sender and recipient names |
| **Phone** | Recipient phone, validated |
| **Product name** | What is being delivered |
| **Address** | Type-ahead autocomplete backed by a real geocoder |
| **Map** | The picked address is pinned on an OpenStreetMap view; tap the map to move the pin and the address is reverse-geocoded to match |
| **Print** | Renders an 80 mm receipt PDF and opens the system print dialog |
| **Preview** | Full-screen preview with print and share actions |

The printed receipt carries a QR code linking to the delivery address on Google Maps,
so a courier can scan the paper slip and navigate straight there.

## Address autocomplete

The app ships with two geocoding providers behind one `AddressService` interface:

**OpenStreetMap Nominatim — the default, no API key, no setup.**

```bash
flutter run
```

**Google Places** — used automatically when you supply a key:

```bash
flutter run --dart-define=GOOGLE_PLACES_API_KEY=your_key_here
```

Enable both *Places API (New)* and *Geocoding API* for that key — the first powers
autocomplete and place details, the second powers reverse geocoding when the user taps
the map. The active provider is shown as a chip next to the address field.

> Nominatim asks for at most one request per second per client. Keystrokes are debounced
> by 450 ms and every request is superseded by the next one, which keeps usage well
> inside that limit for interactive typing. For production traffic, use Google Places or
> host your own Nominatim instance.

## Running it

```bash
flutter pub get
flutter run
```

Targets: Android, iOS, and web (`flutter run -d chrome`). Printing uses the platform's
own print service — AirPrint on iOS, the Android print framework, and the browser print
dialog on web.

Tests:

```bash
flutter test
```

## How it is put together

```
lib/
├── config/app_config.dart              build-time config (API key, user agent)
├── models/
│   ├── address_suggestion.dart         one geocoder candidate
│   └── receipt.dart                    the form's data, plus the maps deep link
├── services/
│   ├── address_service.dart            provider-agnostic interface
│   ├── nominatim_address_service.dart  OpenStreetMap implementation
│   ├── google_places_address_service.dart
│   ├── address_service_factory.dart    picks one based on the build config
│   └── receipt_pdf_service.dart        renders the 80 mm receipt PDF
├── screens/
│   ├── receipt_form_screen.dart        the form
│   └── receipt_preview_screen.dart     PDF preview with print/share
└── widgets/
    ├── address_autocomplete_field.dart debounced type-ahead field
    ├── map_preview.dart                OSM map with a draggable pin
    └── form_section.dart               titled card
```

Swapping in another geocoder means implementing `AddressService` and returning it from
`createAddressService()` — nothing else in the app knows which provider is in use.

## Notes

- The receipt PDF uses `PdfPageFormat.roll80` with an unbounded height, so the paper
  grows with the content. On a thermal receipt printer it fills the roll; sent to an A4
  printer it lands as an 80 mm-wide strip, which is the intended shape.
- The PDF uses the built-in Courier fonts, which cover Latin-1. If you need non-Latin
  scripts on the receipt, bundle a Unicode TTF and pass it to `ReceiptPdfService`.
- Map tiles come from OpenStreetMap's public tile servers. Their tile usage policy
  applies; for real traffic, point `MapPreview` at your own tile source.

## License

MIT — see [LICENSE](LICENSE).
