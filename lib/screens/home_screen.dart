import 'package:flutter/material.dart';

import '../services/address_service.dart';
import '../services/address_service_factory.dart';
import '../services/shipping_rate_service.dart';
import '../services/shipping_rate_service_factory.dart';
import '../theme/app_theme.dart';
import '../widgets/segmented_tabs.dart';
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

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _addressService = createAddressService();
    _shippingService = createShippingRateService(geocoder: _addressService);
  }

  @override
  void dispose() {
    _shippingService.dispose();
    _addressService.dispose();
    super.dispose();
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
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_shipping_outlined,
                          size: 20,
                          color: palette.accent,
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
                  ReceiptFormScreen(addressService: _addressService),
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
