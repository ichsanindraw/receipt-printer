import 'package:flutter/material.dart';

import '../models/printer_settings.dart';
import '../services/address_service.dart';
import '../services/address_service_factory.dart';
import '../services/shipping_rate_service.dart';
import '../services/printer_settings_store.dart';
import '../services/shipping_rate_service_factory.dart';
import '../services/thermal_printer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/segmented_tabs.dart';
import 'printer_settings_screen.dart';
import 'receipt_form_screen.dart';
import 'shipping_screen.dart';

/// Shell holding the two tabs.
///
/// Owns the geocoder so both tabs share one HTTP client, and so the offline
/// shipping estimator can borrow it for coordinates.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AddressService _addressService;
  late final ShippingRateService _shippingService;
  late final ThermalPrinterService _printerService;

  static const _settingsStore = PrinterSettingsStore();

  PrinterSettings _printerSettings = const PrinterSettings();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _addressService = createAddressService();
    _shippingService = createShippingRateService(geocoder: _addressService);
    _printerService = createThermalPrinterService();
    _loadPrinterSettings();
  }

  Future<void> _loadPrinterSettings() async {
    final settings = await _settingsStore.load();
    if (mounted) setState(() => _printerSettings = settings);
  }

  @override
  void dispose() {
    _printerService.disconnect();
    _shippingService.dispose();
    _addressService.dispose();
    super.dispose();
  }

  Future<void> _openPrinterSettings() async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrinterSettingsScreen(
          settings: _printerSettings,
          printerService: _printerService,
          onChanged: (settings) {
            setState(() => _printerSettings = settings);
            _settingsStore.save(settings);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                14,
                AppSpacing.gutter,
                14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _index == 0 ? 'Resi' : 'Ongkir',
                              style: theme.textTheme.displaySmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _index == 0
                                  ? 'Isi detail kiriman, lalu cetak.'
                                  : 'Bandingkan tarif antar kurir.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _openPrinterSettings,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _printerSettings.hasDevice
                                ? palette.accent.withValues(alpha: 0.12)
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _printerSettings.hasDevice
                                  ? Colors.transparent
                                  : palette.hairline,
                            ),
                          ),
                          child: Icon(
                            _printerSettings.hasDevice
                                ? Icons.print_rounded
                                : Icons.print_outlined,
                            size: 20,
                            color: _printerSettings.hasDevice
                                ? palette.accent
                                : palette.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedTabs(
                    labels: const ['Resi', 'Ongkir'],
                    icons: const [
                      Icons.receipt_long_outlined,
                      Icons.calculate_outlined,
                    ],
                    index: _index,
                    onChanged: (value) {
                      FocusScope.of(context).unfocus();
                      setState(() => _index = value);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  ReceiptFormScreen(
                    addressService: _addressService,
                    printerService: _printerService,
                    printerSettings: _printerSettings,
                  ),
                  ShippingScreen(shippingService: _shippingService),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
