import 'package:flutter/material.dart';

/// Widget de selección de variedad con búsqueda y checkboxes ordenados alfabéticamente
class SearchableVariedadSelector extends StatelessWidget {
  final String label;
  final String hint;
  final List<String> options;
  final String? value;
  final Function(String?) onChanged;
  final bool required;
  final bool enabled;

  const SearchableVariedadSelector({
    super.key,
    required this.label,
    required this.hint,
    required this.options,
    required this.onChanged,
    this.value,
    this.required = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            if (required)
              const Text(
                ' *',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Selector Button
        InkWell(
          onTap: enabled ? () => _showVariedadDialog(context) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enabled ? const Color(0xFFD1D5DB) : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? hint,
                    style: TextStyle(
                      fontSize: 14,
                      color: value != null
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color:
                      enabled ? const Color(0xFF6B7280) : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showVariedadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _VariedadSelectionDialog(
        options: options,
        selectedValue: value,
        onSelected: (selected) {
          onChanged(selected);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

/// Diálogo de selección con búsqueda y checkboxes
class _VariedadSelectionDialog extends StatefulWidget {
  final List<String> options;
  final String? selectedValue;
  final Function(String?) onSelected;

  const _VariedadSelectionDialog({
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  State<_VariedadSelectionDialog> createState() =>
      _VariedadSelectionDialogState();
}

class _VariedadSelectionDialogState extends State<_VariedadSelectionDialog> {
  late TextEditingController _searchController;
  late List<String> _sortedOptions;
  late List<String> _filteredOptions;
  String? _tempSelected;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tempSelected = widget.selectedValue;

    // Ordenar alfabéticamente A-Z, manteniendo "Variedad genérica" al inicio si existe
    _sortedOptions = List<String>.from(widget.options);
    _sortedOptions.sort((a, b) {
      // "Variedad genérica" siempre primero
      if (a == 'Variedad genérica') return -1;
      if (b == 'Variedad genérica') return 1;
      // Resto ordenado alfabéticamente (case insensitive)
      return a.toLowerCase().compareTo(b.toLowerCase());
    });

    _filteredOptions = List<String>.from(_sortedOptions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterOptions(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = List<String>.from(_sortedOptions);
      } else {
        _filteredOptions = _sortedOptions
            .where(
                (option) => option.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: isSmallScreen ? screenSize.width * 0.9 : 450,
        constraints: BoxConstraints(
          maxHeight: screenSize.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.eco, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Seleccionar Variedad',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Search Field
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _filterOptions,
                decoration: InputDecoration(
                  hintText: 'Buscar variedad...',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF6B7280)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _filterOptions('');
                          },
                          icon: const Icon(Icons.clear, size: 20),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFF10B981), width: 2),
                  ),
                ),
              ),
            ),

            // Results count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_filteredOptions.length} variedades encontradas',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Ordenadas A-Z',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 16),

            // Options List with Checkboxes
            Flexible(
              child: _filteredOptions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No se encontraron variedades',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Intente con otro término de búsqueda',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredOptions.length,
                      itemBuilder: (context, index) {
                        final option = _filteredOptions[index];
                        final isSelected = option == _tempSelected;
                        final isGeneric = option == 'Variedad genérica';

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _tempSelected = option;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981).withOpacity(0.1)
                                    : null,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Checkbox con estilo de selección única
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF10B981)
                                            : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                      color: isSelected
                                          ? const Color(0xFF10B981)
                                          : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  // Option text
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected || isGeneric
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? const Color(0xFF065F46)
                                            : const Color(0xFF374151),
                                        fontStyle: isGeneric
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                  ),
                                  // Indicator for selected
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      size: 20,
                                      color: Color(0xFF10B981),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  // Clear Button
                  if (_tempSelected != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _tempSelected = null;
                        });
                      },
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Limpiar'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                      ),
                    ),
                  const Spacer(),
                  // Cancel Button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  // Confirm Button
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onSelected(_tempSelected);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Seleccionar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extensión para usar en FormFields existentes
class FormFieldsExtended {
  /// Construye el selector de variedad con búsqueda
  static Widget buildVariedadSelector({
    required String label,
    required String hint,
    required List<String> options,
    required Function(String?) onChanged,
    String? value,
    bool required = false,
    bool enabled = true,
  }) {
    return SearchableVariedadSelector(
      label: label,
      hint: hint,
      options: options,
      value: value,
      onChanged: onChanged,
      required: required,
      enabled: enabled,
    );
  }
}
