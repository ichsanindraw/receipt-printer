import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:printing/printing.dart';

import '../models/address_suggestion.dart';
import '../models/receipt.dart';
import '../services/address_service.dart';
import '../services/receipt_pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/map_preview.dart';
import '../widgets/place_autocomplete_field.dart';
import 'receipt_preview_screen.dart';

/// Fill in the delivery details, then print.
class ReceiptFormScreen extends StatefulWidget {
  const ReceiptFormScreen({super.key, required this.addressService});

  final AddressService addressService;

  @override
  State<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends State<ReceiptFormScreen>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();

  final _numberController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _phoneController = TextEditingController();
  final _productController = TextEditingController();
  final _addressController = TextEditingController();

  AddressSuggestion? _pickedAddress;
  bool _reverseGeocoding = false;
  bool _printing = false;

  static const _pdfService = ReceiptPdfService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _numberController.text = Receipt.generateNumber();
  }

  @override
  void dispose() {
    _numberController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _phoneController.dispose();
    _productController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Receipt _buildReceipt() => Receipt(
    number: _numberController.text.trim(),
    from: _fromController.text.trim(),
    to: _toController.text.trim(),
    phone: _phoneController.text.trim(),
    productName: _productController.text.trim(),
    address: _addressController.text.trim(),
    latitude: _pickedAddress?.latitude,
    longitude: _pickedAddress?.longitude,
    issuedAt: DateTime.now(),
  );

  bool _validate() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) _showMessage('Lengkapi dulu kolom yang ditandai.');
    return valid;
  }

  Future<void> _print() async {
    if (_printing || !_validate()) return;

    final receipt = _buildReceipt();
    setState(() => _printing = true);
    try {
      await Printing.layoutPdf(
        name: 'receipt-${receipt.number}',
        format: ReceiptPdfService.pageFormat,
        onLayout: (format) => _pdfService.build(receipt),
      );
    } catch (error) {
      _showMessage('Gagal membuka printer: $error');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  void _preview() {
    if (!_validate()) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReceiptPreviewScreen(receipt: _buildReceipt()),
      ),
    );
  }

  Future<void> _onMapTap(LatLng point) async {
    setState(() => _reverseGeocoding = true);
    try {
      final result = await widget.addressService.reverse(
        point.latitude,
        point.longitude,
      );
      if (!mounted) return;
      if (result == null) {
        _showMessage('Tidak ada alamat di titik itu.');
        return;
      }
      setState(() {
        _pickedAddress = result;
        _addressController.text = result.description;
      });
    } on AddressServiceException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _reverseGeocoding = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    for (final controller in [
      _fromController,
      _toController,
      _phoneController,
      _productController,
      _addressController,
    ]) {
      controller.clear();
    }
    setState(() {
      _pickedAddress = null;
      _numberController.text = Receipt.generateNumber();
    });
    _showMessage('Formulir dikosongkan.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value, String label) =>
      (value == null || value.trim().isEmpty) ? '$label wajib diisi' : null;

  String? _validatePhone(String? value) {
    final required = _required(value, 'Nomor telepon');
    if (required != null) return required;
    final digits = value!.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return 'Nomor telepon tidak valid';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                4,
                AppSpacing.gutter,
                28,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                AppCard(
                  title: 'Nomor resi',
                  trailing: GestureDetector(
                    onTap: () => setState(
                      () => _numberController.text = Receipt.generateNumber(),
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Icon(
                          Icons.autorenew_rounded,
                          size: 15,
                          color: palette.accent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Buat baru',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.accent,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  children: [
                    AppTextField(
                      label: 'Nomor',
                      controller: _numberController,
                      validator: (v) => _required(v, 'Nomor resi'),
                    ),
                  ],
                ),
                AppCard(
                  title: 'Pengirim & penerima',
                  children: [
                    AppTextField(
                      label: 'Dari',
                      hint: 'Nama pengirim',
                      controller: _fromController,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => _required(v, 'Nama pengirim'),
                    ),
                    const SizedBox(height: AppSpacing.betweenFields),
                    AppTextField(
                      label: 'Kepada',
                      hint: 'Nama penerima',
                      controller: _toController,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => _required(v, 'Nama penerima'),
                    ),
                    const SizedBox(height: AppSpacing.betweenFields),
                    AppTextField(
                      label: 'Telepon',
                      hint: '08xx xxxx xxxx',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                  ],
                ),
                AppCard(
                  title: 'Produk',
                  children: [
                    AppTextField(
                      label: 'Nama produk',
                      hint: 'Apa yang dikirim',
                      controller: _productController,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => _required(v, 'Nama produk'),
                    ),
                  ],
                ),
                AppCard(
                  title: 'Alamat pengiriman',
                  trailing: AppTag(label: widget.addressService.providerLabel),
                  children: [
                    PlaceAutocompleteField(
                      label: 'Alamat',
                      hint: 'Ketik, lalu pilih dari daftar',
                      controller: _addressController,
                      maxLines: 3,
                      onSearch: widget.addressService.search,
                      onResolve: widget.addressService.resolve,
                      validator: (v) => _required(v, 'Alamat'),
                      onSelected: (suggestion) =>
                          setState(() => _pickedAddress = suggestion),
                      onCleared: () {
                        if (_pickedAddress != null) {
                          setState(() => _pickedAddress = null);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.betweenFields),
                    MapPreview(
                      latitude: _pickedAddress?.latitude,
                      longitude: _pickedAddress?.longitude,
                      attribution: widget.addressService.attribution,
                      busy: _reverseGeocoding,
                      onTap: _onMapTap,
                    ),
                    if (_pickedAddress?.hasCoordinates ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.push_pin_outlined,
                              size: 13,
                              color: palette.inkFaint,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_pickedAddress!.latitude!.toStringAsFixed(6)}, '
                              '${_pickedAddress!.longitude!.toStringAsFixed(6)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Center(
                  child: GestureDetector(
                    onTap: _resetForm,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Kosongkan formulir',
                        style: theme.textTheme.bodySmall?.copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: palette.inkFaint,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _actionBar(context),
      ],
    );
  }

  Widget _actionBar(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          12,
          AppSpacing.gutter,
          12,
        ),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Pratinjau',
                icon: Icons.visibility_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: _printing ? null : _preview,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppButton(
                label: _printing ? 'Menyiapkan…' : 'Cetak resi',
                icon: Icons.print_outlined,
                busy: _printing,
                onPressed: _printing ? null : _print,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
