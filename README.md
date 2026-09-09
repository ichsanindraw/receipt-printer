# Receipt Printer

A small cross-platform Flutter app for Indonesian delivery work, in three tabs:

- **Resi** — fill in sender, recipient, product, phone and a map-backed
  address, then print an 80 mm receipt.
- **Ongkir** — compare courier tariffs between two places by weight.
- **Gambar** — print a picture from the gallery on the thermal printer.

One codebase, running on **Android, iOS and the web**.

## Resi

| | |
|---|---|
| **Nomor resi** | Optional. Auto-generated as `RCP-yyyyMMdd-HHmm`, editable, regenerate button; blank omits the line from the print |
| **Dari / Kepada** | Sender and recipient names |
| **Telepon** | Recipient phone, validated |
| **Nama produk** | What is being delivered |
| **Alamat** | Type-ahead autocomplete backed by a real geocoder |
| **Peta** | The picked address is pinned on OpenStreetMap; tap the map to move the pin and the address is reverse-geocoded to match |
| **Cetak resi** | Renders an 80 mm receipt PDF and opens the system print dialog |
| **Pratinjau** | Full-screen preview with print and share actions |

The printed receipt carries a QR code linking to the delivery address on Google
Maps, so a courier can scan the paper slip and navigate straight there.

## Gambar

Pick a photo, see exactly what the printer will produce, print it.

Thermal printers are one bit per dot — a dot is burned or it is not — so a
photograph has to be reduced to black and white. Plain thresholding turns it
into blotches, so images are **Floyd–Steinberg dithered**, trading spatial
resolution for apparent greys. The preview shows the dithered result rather
than the original, because that is what comes out of the printer; it is
rendered with `FilterQuality.none` so the dot pattern is not smoothed away.

Images are scaled to the print head width — 576 dots at 80 mm, 384 at 58 mm —
and capped at 1400 dots (about 175 mm) so one picture cannot run off a metre
of paper. Preparation runs in a background isolate; dithering a full-size
photo on the UI isolate drops frames.

## Printers

Tap the printer icon in the header to open printer settings: pair a Bluetooth
thermal printer, choose 58 or 80 mm paper, set copies, toggle the auto-cut, and
run a test print.

There are two print paths, and the app picks one automatically:

| Printer paired | What happens |
|---|---|
| Yes | The receipt is rendered as **ESC/POS** commands and sent straight to the thermal printer |
| No | Falls back to the **system print dialog** — AirPrint, Android Print, or the browser dialog — with the PDF receipt |

The fallback matters: `Printing.layoutPdf` reaches office and network printers
but cannot talk to a Bluetooth thermal printer, and the Bluetooth plugin has no
web support at all. Keeping both means every platform can print something.

- **Android** — pair the printer in system Bluetooth settings first; the app
  lists paired devices. `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` are requested at
  runtime on Android 12+.
- **iOS** — nearby BLE printers are listed directly, no pairing step.
- **Web** — Bluetooth printing is unavailable; the settings screen says so and
  the browser print dialog is used instead.

> Bluetooth printing has not been verified against physical hardware — there was
> no thermal printer available, and the iOS Simulator has no Bluetooth adapter.
> The ESC/POS byte stream, the settings model and the settings UI are covered by
> tests; the transport itself needs a real printer to confirm.

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

### Icon and splash

The mark — a receipt slip with a torn edge and a map pin, the two things the
app does — is drawn from the same tokens by
[`tool/generate_brand_assets.py`](tool/generate_brand_assets.py), so it cannot
drift from the palette. To change it:

```bash
python3 tool/generate_brand_assets.py    # redraws the source art
dart run flutter_launcher_icons          # iOS, Android and web icons
dart run flutter_native_splash:create    # native launch screens
```

The script draws the mark twice — light-on-dark for the icon and the dark
splash, dark-on-light for the light splash — so it reads on either ground. Two
sizing rules are baked in, both learned the hard way:

- The **Android adaptive foreground** is drawn at 85% coverage because
  `flutter_launcher_icons` wraps it in a further 16% inset. At the usual 50%
  the icon came out about a third of the canvas.
- The **splash art** is a 640px source, because `flutter_native_splash` treats
  it as the 4x asset. A 1024px source renders a ~205dp logo; 640px lands a
  conventional ~145dp.

Splash grounds match the app's own scaffold colours — `#F4F3F0` light,
`#121110` dark — so the launch screen hands over to the first frame without a
flash, in both modes and on Android 12+'s `windowSplashScreen` API.

> **If you still see a white flash on iOS after changing the splash:** iOS
> caches the launch screen and the cache survives reinstalls. Test on a
> simulator that has never had the app, or erase the device. The storyboard
> itself is fine — this bit us during development and cost an hour.

## How it is put together

```
lib/
├── config/app_config.dart              build-time config (API keys, user agent)
├── theme/app_theme.dart                colours, type scale, shapes
├── models/
│   ├── address_suggestion.dart         one place: label, id, coordinates
│   ├── receipt.dart                    the form's data, plus the maps deep link
│   ├── printer_settings.dart           paired printer, paper width, copies
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
│   ├── receipt_pdf_service.dart        renders the 80 mm receipt PDF
│   ├── receipt_escpos_service.dart     renders the same receipt as ESC/POS
│   ├── image_print_service.dart        dithers a photo to 1-bit ESC/POS raster
│   ├── thermal_printer_service.dart    Bluetooth transport (io/web split)
│   └── printer_settings_store.dart     persists the paired printer
├── screens/
│   ├── home_screen.dart                tab shell, owns the shared services
│   ├── receipt_form_screen.dart        Resi tab
│   ├── shipping_screen.dart            Ongkir tab
│   ├── printer_settings_screen.dart    pair a printer, paper, test print
│   ├── print_image_screen.dart         Gambar tab
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
- Receipt values print at double height with single width, in font A. At the
  printer's base size they were too small to read on paper; single width keeps
  48 characters per line so long addresses still wrap where they did. Font A
  has to be stated explicitly on every value: the generator only emits a font
  command when `fontType` is non-null, so a null one silently inherits font B
  from the caption above it.
- Print jobs are written to Bluetooth in 512-byte chunks 20 ms apart, and
  images are rasterised in 64-row bands. A full-width picture is tens of
  kilobytes; sent in one write it overran the printer's buffer, which printed
  the top of the image and dropped the rest.

## License

MIT — see [LICENSE](LICENSE). Plus Jakarta Sans is licensed under the SIL Open
Font License; see [assets/fonts/OFL.txt](assets/fonts/OFL.txt).
