// Searchable Dropdown Widget
// Replaces DropdownButtonFormField for large lists (100+ items)
// Provides a text field with search/filter functionality and a scrollable overlay list
// SafeArms Frontend

import 'package:flutter/material.dart';

/// A single item in the searchable dropdown
class SearchableDropdownItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;

  const SearchableDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });
}

/// A dropdown widget with built-in search/filter functionality.
/// Scales well for 100+ items by showing a filtered, scrollable overlay.
class SearchableDropdown<T> extends StatefulWidget {
  final List<SearchableDropdownItem<T>> items;
  final T? value;
  final String hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final bool enabled;

  const SearchableDropdown({
    super.key,
    required this.items,
    this.value,
    this.hintText = 'Search...',
    this.labelText,
    this.prefixIcon,
    required this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  List<SearchableDropdownItem<T>> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _updateDisplayText();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.items != widget.items) {
      _filteredItems = widget.items;
      _updateDisplayText();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _updateDisplayText() {
    if (widget.value != null) {
      final selected = widget.items.where((item) => item.value == widget.value);
      if (selected.isNotEmpty) {
        _searchController.text = selected.first.label;
      }
    } else {
      _searchController.clear();
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _openDropdown();
    } else {
      // Delay closing to allow tap registration on overlay items
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_focusNode.hasFocus) {
          _closeDropdown();
          _updateDisplayText();
        }
      });
    }
  }

  void _openDropdown() {
    if (_isOpen || !widget.enabled) return;
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
    _filteredItems = widget.items;
    _isOpen = true;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeDropdown() {
    if (!_isOpen) return;
    _isOpen = false;
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredItems = widget.items.where((item) {
          return item.label.toLowerCase().contains(lowerQuery) ||
              (item.subtitle?.toLowerCase().contains(lowerQuery) ?? false);
        }).toList();
      }
    });
    // Rebuild overlay with filtered items
    _overlayEntry?.markNeedsBuild();
  }

  void _onItemSelected(SearchableDropdownItem<T> item) {
    widget.onChanged(item.value);
    _searchController.text = item.label;
    _focusNode.unfocus();
    _closeDropdown();
  }

  void _onClear() {
    widget.onChanged(null);
    _searchController.clear();
    _filteredItems = widget.items;
    _overlayEntry?.markNeedsBuild();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) {
        const maxHeight = 250.0;
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: Material(
              elevation: 8,
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: maxHeight),
                child: _filteredItems.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No results found',
                          style: TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isSelected = item.value == widget.value;
                          return InkWell(
                            onTap: () => _onItemSelected(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1E88E5)
                                        .withValues(alpha: 0.15)
                                    : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: const Color(0xFF37404F)
                                        .withValues(alpha: 0.5),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (item.icon != null) ...[
                                    Icon(
                                      item.icon,
                                      color: isSelected
                                          ? const Color(0xFF42A5F5)
                                          : const Color(0xFF78909C),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            color: isSelected
                                                ? const Color(0xFF42A5F5)
                                                : Colors.white,
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.subtitle != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            item.subtitle!,
                                            style: const TextStyle(
                                              color: Color(0xFF78909C),
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check,
                                      color: Color(0xFF42A5F5),
                                      size: 18,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: widget.value,
      validator: widget.validator != null
          ? (_) => widget.validator!(widget.value)
          : null,
      builder: (FormFieldState<T> field) {
        return CompositedTransformTarget(
          link: _layerLink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                focusNode: _focusNode,
                enabled: widget.enabled,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(color: Color(0xFF78909C)),
                  labelText: widget.labelText,
                  labelStyle: const TextStyle(color: Color(0xFF78909C)),
                  prefixIcon: widget.prefixIcon != null
                      ? Icon(widget.prefixIcon,
                          color: const Color(0xFF78909C), size: 20)
                      : const Icon(Icons.search,
                          color: Color(0xFF78909C), size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.value != null)
                        IconButton(
                          icon: const Icon(Icons.clear,
                              color: Color(0xFF78909C), size: 18),
                          onPressed: _onClear,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      Icon(
                        _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: const Color(0xFF78909C),
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2A3040),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: field.hasError
                          ? const Color(0xFFE85C5C)
                          : const Color(0xFF37404F),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: field.hasError
                          ? const Color(0xFFE85C5C)
                          : const Color(0xFF37404F),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: field.hasError
                          ? const Color(0xFFE85C5C)
                          : const Color(0xFF1E88E5),
                      width: 2,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2A3040)),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFFE85C5C), width: 2),
                  ),
                ),
                onChanged: _onSearchChanged,
                onTap: () {
                  if (!_isOpen) _openDropdown();
                },
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    field.errorText!,
                    style: const TextStyle(
                      color: Color(0xFFE85C5C),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
