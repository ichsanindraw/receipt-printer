import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:printing/printing.dart';

import '../models/address_suggestion.dart';
import '../models/customer.dart';
import '../models/printer_settings.dart';
import '../models/receipt.dart';
import '../services/address_service.dart';
import '../services/customer_history_service.dart';
import '../services/receipt_escpos_service.dart';
import '../services/receipt_pdf_service.dart';
import '../services/thermal_printer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/customer_history_sheet.dart';
import '../widgets/map_preview.dart';
import '../widgets/place_autocomplete_field.dart';
import 'receipt_preview_screen.dart';

/// Fill in the delivery details, then print.
class ReceiptFormScreen extends StatefulWidget {
  const ReceiptFormScreen({
    super.key,
    required this.addressService,
    required this.printerService,
    required this.printerSettings,
    required this.customerHistoryService,
  });

  final AddressService addressService;
  final ThermalPrinterService printerService;

  /// When a thermal printer is paired the receipt goes straight to it;
  /// otherwise printing falls back to the platform print dialog.
  final PrinterSettings printerSettings;

  /// Local history of recipients who have ordered before, so a repeat order
  /// can be searched and applied to the form in one tap.
  final CustomerHistoryService customerHistoryService;

  @override
  State<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends State<ReceiptFormScreen>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();

  // The sender is almost always the same business, so it starts pre-filled
  // rather than blank — "Kosongkan formulir" restores these two rather than
  // clearing them, since they're a standing default, not a draft value.
  static const _defaultFromName = 'Seanite';
  static const _defaultFromPhone = '08131369382';

  final _numberController = TextEditingController();
  final _fromController = TextEditingController();
  final _fromPhoneController = TextEditingController();
  final _toController = TextEditingController();
  final _toPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  /// A delivery is rarely just one item, so products are a growable list of
  /// fields rather than a single one. Kept `final` and mutated in place
  /// (rather than reassigned) so dispose() always sees every controller ever
  /// created, including ones added after the initial build.
  final List<TextEditingController> _productControllers = [];

  AddressSuggestion? _pickedAddress;
  bool _reverseGeocoding = false;
  bool _printing = false;

  /// Whether printing this receipt also saves its recipient to the local
  /// customer history. Checked by default since that is the point of the
  /// history, but a one-off order may not need to be remembered.
  bool _saveToHistory = true;

  static const _pdfService = ReceiptPdfService();
  static const _escPosService = ReceiptEscPosService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _numberController.text = Receipt.generateNumber();
    _fromController.text = _defaultFromName;
    _fromPhoneController.text = _defaultFromPhone;
    _productControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _numberController.dispose();
    _fromController.dispose();
    _fromPhoneController.dispose();
    _toController.dispose();
    _toPhoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    for (final controller in _productControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Receipt _buildReceipt() => Receipt(
    number: _numberController.text.trim(),
    from: _fromController.text.trim(),
    fromPhone: _fromPhoneController.text.trim(),
    to: _toController.text.trim(),
    toPhone: _toPhoneController.text.trim(),
    products: _productControllers
        .map((controller) => controller.text.trim())
        .where((product) => product.isNotEmpty)
        .toList(),
    address: _addressController.text.trim(),
    notes: _notesController.text.trim(),
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
    if (_saveToHistory) {
      // Fire-and-forget: saving history is a nice-to-have, not something
      // that should ever block or crash printing — same stance as
      // PrinterSettingsStore for its own platform-channel failures.
      unawaited(_recordCustomerHistory(receipt));
    }

    final settings = widget.printerSettings;
    setState(() => _printing = true);
    try {
      if (settings.hasDevice && widget.printerService.isSupported) {
        await _printToThermal(receipt, settings);
      } else {
        await _printToSystemDialog(receipt);
      }
    } on ThermalPrinterException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Gagal mencetak: $error');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _recordCustomerHistory(Receipt receipt) async {
    try {
      await widget.customerHistoryService.saveFromReceipt(receipt);
    } catch (error) {
      debugPrint('Could not save customer history: $error');
    }
  }

  Future<void> _printToThermal(
    Receipt receipt,
    PrinterSettings settings,
  ) async {
    final bytes = await _escPosService.build(
      receipt,
      paperWidth: settings.paperWidth,
    );
    await widget.printerService.printBytes(
      bytes,
      address: settings.deviceAddress!,
      copies: settings.copies,
    );
    if (mounted) {
      _showMessage('Resi dikirim ke ${settings.deviceName ?? 'printer'}.');
    }
  }

  Future<void> _printToSystemDialog(Receipt receipt) async {
    await Printing.layoutPdf(
      name: receipt.fileLabel,
      format: ReceiptPdfService.pageFormat,
      onLayout: (format) => _pdfService.build(receipt),
    );
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

  Future<void> _openCustomerHistory() async {
    FocusScope.of(context).unfocus();
    final customer = await CustomerHistorySheet.show(
      context,
      widget.customerHistoryService,
    );
    if (customer != null && mounted) _applyCustomer(customer);
  }

  void _applyCustomer(Customer customer) {
    setState(() {
      _toController.text = customer.name;
      _toPhoneController.text = customer.phone;
      _addressController.text = customer.address;
      _pickedAddress = customer.hasCoordinates
          ? AddressSuggestion(
              description: customer.address,
              latitude: customer.latitude,
              longitude: customer.longitude,
            )
          : null;
      _notesController.text = customer.notes;

      for (final controller in _productControllers) {
        controller.dispose();
      }
      final products = customer.products.isEmpty ? [''] : customer.products;
      _productControllers
        ..clear()
        ..addAll(products.map((text) => TextEditingController(text: text)));
    });
    _showMessage('Data ${customer.name} diterapkan ke formulir.');
  }

  void _addProduct() {
    setState(() => _productControllers.add(TextEditingController()));
  }

  void _removeProduct(int index) {
    setState(() => _productControllers.removeAt(index).dispose());
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    for (final controller in [
      _toController,
      _toPhoneController,
      _addressController,
      _notesController,
    ]) {
      controller.clear();
    }
    for (final controller in _productControllers) {
      controller.dispose();
    }
    setState(() {
      _pickedAddress = null;
      _numberController.text = Receipt.generateNumber();
      _fromController.text = _defaultFromName;
      _fromPhoneController.text = _defaultFromPhone;
      _productControllers
        ..clear()
        ..add(TextEditingController());
      _saveToHistory = true;
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

  String? _validatePhone(String? value, String label) {
    final required = _required(value, label);
    if (required != null) return required;
    final digits = value!.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return '$label tidak valid';
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
                      helper: 'Opsional — kosongkan kalau tidak dipakai.',
                    ),
                  ],
                ),
                AppCard(
                  title: 'Pengirim & penerima',
                  trailing: GestureDetector(
                    onTap: _openCustomerHistory,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 15,
                          color: palette.accent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Riwayat',
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
                      label: 'Dari',
                      hint: 'Nama pengirim',
                      controller: _fromController,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => _required(v, 'Nama pengirim'),
                    ),
                    const SizedBox(height: AppSpacing.betweenFields),
                    AppTextField(
                      label: 'No. HP pengirim',
                      hint: '08xx xxxx xxxx',
                      controller: _fromPhoneController,
                      keyboardType: TextInputType.phone,
                      validator: (v) => _validatePhone(v, 'No. HP pengirim'),
                    ),
                    const SizedBox(height: AppSpacing.gutter),
                    AppTextField(
                      label: 'Kepada',
                      hint: 'Nama penerima',
                      controller: _toController,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => _required(v, 'Nama penerima'),
                    ),
                    const SizedBox(height: AppSpacing.betweenFields),
                    AppTextField(
                      label: 'No. HP penerima',
                      hint: '08xx xxxx xxxx',
                      controller: _toPhoneController,
                      keyboardType: TextInputType.phone,
                      validator: (v) => _validatePhone(v, 'No. HP penerima'),
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
                      helper:
                          'Bisa ditulis manual kalau jalannya tidak ada di peta.',
                      controller: _addressController,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
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
                AppCard(
                  title: 'Produk',
                  children: [
                    for (var i = 0; i < _productControllers.length; i++) ...[
                      if (i > 0)
                        const SizedBox(height: AppSpacing.betweenFields),
                      AppTextField(
                        label: i == 0 ? 'Nama produk' : 'Produk ${i + 1}',
                        hint: 'Apa yang dikirim',
                        controller: _productControllers[i],
                        textCapitalization: TextCapitalization.sentences,
                        // Only the first product is required; extra rows are
                        // purely additive and a blank one is simply dropped.
                        validator: i == 0
                            ? (v) => _required(v, 'Nama produk')
                            : null,
                        suffix: _productControllers.length > 1
                            ? GestureDetector(
                                onTap: () => _removeProduct(i),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: palette.inkMuted,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Center(
                        child: GestureDetector(
                          onTap: _addProduct,
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 16,
                                color: palette.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Tambah produk',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: palette.accent,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                AppCard(
                  title: 'Catatan',
                  children: [
                    AppTextField(
                      label: 'Catatan',
                      hint: 'Instruksi tambahan, kalau ada',
                      helper: 'Opsional.',
                      controller: _notesController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 4,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _saveToHistoryToggle(context),
            const SizedBox(height: 10),
            Row(
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
          ],
        ),
      ),
    );
  }

  Widget _saveToHistoryToggle(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);

    return GestureDetector(
      onTap: _printing
          ? null
          : () => setState(() => _saveToHistory = !_saveToHistory),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _saveToHistory
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: _saveToHistory
                    ? theme.colorScheme.primary
                    : palette.hairline,
                width: 1.4,
              ),
            ),
            child: _saveToHistory
                ? Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: theme.colorScheme.onPrimary,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Simpan pelanggan ini ke riwayat',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
