import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfessionalDataTable extends StatefulWidget {
  final List<DataTableColumn> columns;
  final List<Map<String, dynamic>> data;
  final Function(Map<String, dynamic>)? onRowTap;
  final List<TableFilter>? filters;
  final bool showSearch;
  final String searchPlaceholder;

  const ProfessionalDataTable({
    Key? key,
    required this.columns,
    required this.data,
    this.onRowTap,
    this.filters,
    this.showSearch = true,
    this.searchPlaceholder = 'Search...',
  }) : super(key: key);

  @override
  State<ProfessionalDataTable> createState() => _ProfessionalDataTableState();
}

class _ProfessionalDataTableState extends State<ProfessionalDataTable> {
  String _searchQuery = '';
  Map<String, String?> _selectedFilters = {};
  int _currentPage = 0;
  final int _rowsPerPage = 50;

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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Modern Search and Filters Bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Search Box with modern styling
                  if (widget.showSearch)
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: widget.searchPlaceholder,
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _currentPage = 0; // Reset to first page
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          style: GoogleFonts.poppins(fontSize: 14),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _currentPage = 0;
                            });
                          },
                        ),
                      ),
                    ),
                  
                  // Filters with modern styling
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
                    'Showing ${_filteredData.isEmpty ? 0 : _currentPage * _rowsPerPage + 1}-${(_currentPage * _rowsPerPage + _paginatedData.length)} of ${_filteredData.length} results',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_totalPages > 1) _buildPagination(),
                ],
              ),
            ],
          ),
        ),

        // Beautiful Table
        Expanded(
          child: _filteredData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No data found',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your search or filters',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF94A3B8),
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
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: _buildTable(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(TableFilter filter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilters[filter.key] ?? 'all',
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 20),
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF1E293B),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
            color: _currentPage > 0 ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
            splashRadius: 20,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Page ${_currentPage + 1} of $_totalPages',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: _currentPage < _totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
            color: _currentPage < _totalPages - 1 ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
            splashRadius: 20,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        for (int i = 0; i < widget.columns.length; i++)
          i: FixedColumnWidth(widget.columns[i].width),
      },
      children: [
        // Beautiful Header Row with gradient
        TableRow(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF3B82F6),
                const Color(0xFF2563EB),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          children: widget.columns.map((column) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                column.label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            );
          }).toList(),
        ),

        // Data Rows with alternating colors and hover effect
        ..._paginatedData.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final isEven = index % 2 == 0;
          
          return TableRow(
            decoration: BoxDecoration(
              color: isEven ? Colors.white : const Color(0xFFF8FAFC),
            ),
            children: widget.columns.map((column) {
              final cellWidget = column.builder != null
                  ? column.builder!(row)
                  : Text(
                      row[column.key]?.toString() ?? '-',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    );

              return InkWell(
                onTap: widget.onRowTap != null
                    ? () => widget.onRowTap!(row)
                    : null,
                hoverColor: const Color(0xFFEFF6FF),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: cellWidget,
                ),
              );
            }).toList(),
          );
        }).toList(),
      ],
    );
  }
}

// Column definition
class DataTableColumn {
  final String key;
  final String label;
  final double width;
  final Widget Function(Map<String, dynamic>)? builder;

  const DataTableColumn({
    required this.key,
    required this.label,
    required this.width,
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
