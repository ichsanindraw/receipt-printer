import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:printing/printing.dart';

import '../config/app_config.dart';
import '../models/address_suggestion.dart';
import '../models/receipt.dart';
import '../services/address_service.dart';
import '../services/address_service_factory.dart';
import '../services/receipt_pdf_service.dart';
import '../widgets/address_autocomplete_field.dart';
import '../widgets/form_section.dart';
import '../widgets/map_preview.dart';
import 'receipt_preview_screen.dart';

/// The single screen of the app: fill the form, then print.
class ReceiptFormScreen extends StatefulWidget {
  const ReceiptFormScreen({super.key});

  @override
  State<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends State<ReceiptFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _numberController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _phoneController = TextEditingController();
  final _productController = TextEditingController();
  final _addressController = TextEditingController();

  late final AddressService _addressService;

  AddressSuggestion? _pickedAddress;
  bool _reverseGeocoding = false;
  bool _printing = false;

  static const _pdfService = ReceiptPdfService();

  @override
  void initState() {
    super.initState();
    _addressService = createAddressService();
    _numberController.text = Receipt.generateNumber();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _numberController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _phoneController.dispose();
    _productController.dispose();
    _addressController.dispose();
    _addressService.dispose();
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
    if (!valid) {
      _showMessage('Please complete the highlighted fields.');
    }
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
      _showMessage('Could not open the printer: $error');
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
      final result = await _addressService.reverse(
        point.latitude,
        point.longitude,
      );
      if (!mounted) return;
      if (result == null) {
        _showMessage('No address found at that point.');
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
    _showMessage('Form cleared.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value, String label) =>
      (value == null || value.trim().isEmpty) ? '$label is required' : null;

  String? _validatePhone(String? value) {
    final required = _required(value, 'Phone number');
    if (required != null) return required;
    final digits = value!.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return 'Enter a valid phone number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Clear form',
            onPressed: _resetForm,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              FormSection(
                title: 'RECEIPT',
                icon: Icons.receipt_long_outlined,
                trailing: IconButton(
                  icon: const Icon(Icons.autorenew, size: 20),
                  tooltip: 'Generate a new number',
                  onPressed: () => setState(
                    () => _numberController.text = Receipt.generateNumber(),
                  ),
                ),
                children: [
                  TextFormField(
                    controller: _numberController,
                    decoration: const InputDecoration(
                      labelText: 'Receipt number',
                      prefixIcon: Icon(Icons.tag),
                    ),
                    validator: (v) => _required(v, 'Receipt number'),
                  ),
                ],
              ),
              FormSection(
                title: 'SENDER & RECIPIENT',
                icon: Icons.swap_horiz,
                children: [
                  TextFormField(
                    controller: _fromController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'From (sender name)',
                      prefixIcon: Icon(Icons.outbox_outlined),
                    ),
                    validator: (v) => _required(v, 'Sender name'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _toController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'To (recipient name)',
                      prefixIcon: Icon(Icons.move_to_inbox_outlined),
                    ),
                    validator: (v) => _required(v, 'Recipient name'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: _validatePhone,
                  ),
                ],
              ),
              FormSection(
                title: 'PRODUCT',
                icon: Icons.inventory_2_outlined,
                children: [
                  TextFormField(
                    controller: _productController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Product name',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                    validator: (v) => _required(v, 'Product name'),
                  ),
                ],
              ),
              FormSection(
                title: 'DELIVERY ADDRESS',
                icon: Icons.map_outlined,
                trailing: Chip(
                  label: Text(
                    _addressService.providerLabel,
                    style: theme.textTheme.labelSmall,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                children: [
                  AddressAutocompleteField(
                    controller: _addressController,
                    service: _addressService,
                    onSelected: (suggestion) =>
                        setState(() => _pickedAddress = suggestion),
                    onCleared: () {
                      if (_pickedAddress != null) {
                        setState(() => _pickedAddress = null);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  MapPreview(
                    latitude: _pickedAddress?.latitude,
                    longitude: _pickedAddress?.longitude,
                    attribution: _addressService.attribution,
                    busy: _reverseGeocoding,
                    onTap: _onMapTap,
                  ),
                  if (_pickedAddress?.hasCoordinates ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Pinned at ${_pickedAddress!.latitude!.toStringAsFixed(6)}, '
                        '${_pickedAddress!.longitude!.toStringAsFixed(6)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _actionBar(theme),
    );
  }

  Widget _actionBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _printing ? null : _preview,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Preview'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _printing ? null : _print,
                icon: _printing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.print_outlined),
                label: Text(_printing ? 'Preparing…' : 'Print Receipt'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
