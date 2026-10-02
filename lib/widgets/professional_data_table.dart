import 'package:flutter/material.dart';

class ProfessionalDataTable extends StatefulWidget {
  final List<DataTableColumn> columns;
  final List<Map<String, dynamic>> data;
  final Function(Map<String, dynamic>)? onRowTap;
  final List<TableFilter>? filters;
  final bool showSearch;
  final String searchPlaceholder;
  final String? tableKey; // Unique key to persist pagination state

  const ProfessionalDataTable({
    Key? key,
    required this.columns,
    required this.data,
    this.onRowTap,
    this.filters,
    this.showSearch = true,
    this.searchPlaceholder = 'Search...',
    this.tableKey,
  }) : super(key: key);

  @override
  State<ProfessionalDataTable> createState() => _ProfessionalDataTableState();
}

class _ProfessionalDataTableState extends State<ProfessionalDataTable> {
  String _searchQuery = '';
  Map<String, String?> _selectedFilters = {};
  int _currentPage = 0;
  final int _rowsPerPage = 25;
  late ScrollController _horizontalScrollController;
  late ScrollController _verticalScrollController;
  
  // Static map to persist pagination state across rebuilds
  static final Map<String, int> _pageStateCache = {};

  // Clean modern color palette
  static const _headerColor = Color(0xFF00BFA6); // Teal accent
  static const _headerText = Colors.white;
  static const _bodyText = Color(0xFF212121);
  static const _secondaryText = Color(0xFF757575);
  static const _borderColor = Color(0xFFE0E0E0);
  static const _hoverColor = Color(0xFFF5F5F5);
  static const _backgroundColor = Color(0xFFFAFAFA);

  List<Map<String, dynamic>> get _filteredData {
    var filtered = widget.data;

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((row) {
        return widget.columns.any((column) {
          final value = row[column.key]?.toString().toLowerCase() ?? '';
          return value.contains(_searchQuery.toLowerCase());
        });
      }).toList();
    }

    // Apply filters
    if (widget.filters != null) {
      for (var filter in widget.filters!) {
        final selectedValue = _selectedFilters[filter.key];
        if (selectedValue != null && selectedValue != 'all') {
          filtered = filtered.where((row) {
            // Handle numeric range filters for shareValue
            if (filter.key == 'shareValue' && row.containsKey('shareValue')) {
              final value = (row['shareValue'] as num?)?.toDouble() ?? 0.0;
              switch (selectedValue) {
                case 'zero':
                  return value == 0;
                case 'below_150k':
                  return value > 0 && value < 150000;
                case '150k_500k':
                  return value >= 150000 && value < 500000;
                case '500k_1m':
                  return value >= 500000 && value < 1000000;
                case '1m_2m':
                  return value >= 1000000 && value < 2000000;
                case 'above_2m':
                  return value >= 2000000;
                default:
                  return true;
              }
            }
            // Handle numeric range filters for savingsBalance
            if (filter.key == 'savingsBalance' && row.containsKey('savingsBalance')) {
              final value = (row['savingsBalance'] as num?)?.toDouble() ?? 0.0;
              switch (selectedValue) {
                case 'zero':
                  return value == 0;
                case 'below_100k':
                  return value > 0 && value < 100000;
                case '100k_500k':
                  return value >= 100000 && value < 500000;
                case '500k_1m':
                  return value >= 500000 && value < 1000000;
                case 'above_1m':
                  return value >= 1000000;
                default:
                  return true;
              }
            }
            // Default string comparison for other filters
            return row[filter.key]?.toString() == selectedValue;
          }).toList();
        }
      }
    }

    return filtered;
  }

  List<Map<String, dynamic>> get _paginatedData {
    // Ensure current page is within valid range
    if (_currentPage >= _totalPages && _totalPages > 0) {
      _currentPage = _totalPages - 1;
    }
    if (_currentPage < 0) {
      _currentPage = 0;
    }
    
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, _filteredData.length);
    
    // Safety check to prevent RangeError
    if (startIndex >= _filteredData.length) {
      return [];
    }
    
    return _filteredData.sublist(startIndex, endIndex);
  }

  int get _totalPages => _filteredData.isEmpty ? 1 : (_filteredData.length / _rowsPerPage).ceil();

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _verticalScrollController = ScrollController();
    
    // Restore pagination state if available
    if (widget.tableKey != null && _pageStateCache.containsKey(widget.tableKey)) {
      _currentPage = _pageStateCache[widget.tableKey!]!;
    }
  }

  @override
  void dispose() {
    // Save pagination state before disposing
    if (widget.tableKey != null) {
      _pageStateCache[widget.tableKey!] = _currentPage;
    }
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Clean Search and Filters Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: _borderColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Clean Search Box
                  if (widget.showSearch)
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: _backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _borderColor),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: widget.searchPlaceholder,
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              color: _secondaryText,
                            ),
                            prefixIcon: const Icon(Icons.search, color: _secondaryText, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _currentPage = 0;
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 14, color: _bodyText),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _currentPage = 0;
                            });
                          },
                        ),
                      ),
                    ),
                  
                  // Clean Filters
                  if (widget.filters != null) ...[
                    const SizedBox(width: 12),
                    ...widget.filters!.map((filter) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _buildFilterDropdown(filter),
                      );
                    }).toList(),
                  ],
                ],
              ),
              
              // Results count and pagination
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${_filteredData.isEmpty ? 0 : _currentPage * _rowsPerPage + 1}-${(_currentPage * _rowsPerPage + _paginatedData.length)} of ${_filteredData.length} entries',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_totalPages > 1) _buildPagination(),
                ],
              ),
            ],
          ),
        ),

        // Clean Table
        Expanded(
          child: _filteredData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'No data found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try adjusting your search or filters',
                        style: TextStyle(
                          fontSize: 13,
                          color: _secondaryText,
                        ),
                      ),
                      if (_searchQuery.isNotEmpty || _selectedFilters.values.any((v) => v != null && v != 'all'))
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _selectedFilters.clear();
                                _currentPage = 0;
                              });
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Clear filters'),
                          ),
                        ),
                    ],
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildTable(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(TableFilter filter) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilters[filter.key] ?? 'all',
          icon: const Icon(Icons.keyboard_arrow_down, color: _secondaryText, size: 20),
          style: const TextStyle(
            fontSize: 13,
            color: _bodyText,
            fontWeight: FontWeight.w500,
          ),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Text('All ${filter.label}'),
            ),
            ...filter.options.map((option) {
              return DropdownMenuItem(
                value: option.value,
                child: Text(option.label),
              );
            }).toList(),
          ],
          onChanged: (value) {
            setState(() {
              _selectedFilters[filter.key] = value;
              _currentPage = 0;
            });
          },
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      children: [
        // Previous button
        Material(
          color: _currentPage > 0 ? Colors.white : _backgroundColor,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: _borderColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.chevron_left,
                size: 20,
                color: _currentPage > 0 ? _bodyText : _secondaryText,
              ),
            ),
          ),
        ),
        
        // Page info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Page ${_currentPage + 1} of $_totalPages',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _bodyText,
            ),
          ),
        ),
        
        // Next button
        Material(
          color: _currentPage < _totalPages - 1 ? Colors.white : _backgroundColor,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _currentPage < _totalPages - 1 ? () => setState(() => _currentPage++) : null,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: _borderColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: _currentPage < _totalPages - 1 ? _bodyText : _secondaryText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    // Use LayoutBuilder to get available width
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        
        return Column(
          children: [
            // Sticky Header Row
            Container(
              width: availableWidth,
              decoration: const BoxDecoration(
                color: _headerColor,
              ),
              child: Row(
                children: widget.columns.map((column) {
                  return Expanded(
                    flex: column.flex,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF00AB94), width: 2),
                        ),
                      ),
                      child: Text(
                        column.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _headerText,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            // Data Rows (scrollable)
            Expanded(
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                child: Column(
                  children: _paginatedData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    final isEven = index % 2 == 0;
                    
                    return InkWell(
                      onTap: widget.onRowTap != null ? () => widget.onRowTap!(row) : null,
                      hoverColor: _hoverColor,
                      child: Container(
                        width: availableWidth,
                        decoration: BoxDecoration(
                          color: isEven ? Colors.white : _backgroundColor,
                          border: const Border(
                            bottom: BorderSide(
                              color: _borderColor,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: widget.columns.map((column) {
                            final cellWidget = column.builder != null
                                ? column.builder!(row)
                                : Text(
                                    row[column.key]?.toString() ?? '-',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _bodyText,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  );

                            return Expanded(
                              flex: column.flex,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: cellWidget,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Column definition
class DataTableColumn {
  final String key;
  final String label;
  final double? width; // Now optional - will use flex if not provided
  final int flex; // Flex weight for responsive columns
  final Widget Function(Map<String, dynamic>)? builder;

  const DataTableColumn({
    required this.key,
    required this.label,
    this.width,
    this.flex = 1,
    this.builder,
  });
}

// Filter definition
class TableFilter {
  final String key;
  final String label;
  final List<FilterOption> options;

  const TableFilter({
    required this.key,
    required this.label,
    required this.options,
  });
}

// Filter option
class FilterOption {
  final String value;
  final String label;

  const FilterOption({
    required this.value,
    required this.label,
  });
}
