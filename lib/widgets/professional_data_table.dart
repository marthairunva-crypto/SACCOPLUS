import 'dart:math' as math;
import 'package:flutter/material.dart';

class ProfessionalDataTable extends StatefulWidget {
  final List<DataTableColumn> columns;
  final List<Map<String, dynamic>> data;
  final Function(Map<String, dynamic>)? onRowTap;
  final List<TableFilter>? filters;
  final bool showSearch;
  final String searchPlaceholder;
  final String? tableKey; // Unique key to persist pagination state

  /// Extra space under the last row so floating buttons (e.g. "Add Member")
  /// never cover the data.
  final double listBottomPadding;

  const ProfessionalDataTable({
    Key? key,
    required this.columns,
    required this.data,
    this.onRowTap,
    this.filters,
    this.showSearch = true,
    this.searchPlaceholder = 'Search...',
    this.tableKey,
    this.listBottomPadding = 88,
  }) : super(key: key);

  @override
  State<ProfessionalDataTable> createState() => _ProfessionalDataTableState();
}

class _ProfessionalDataTableState extends State<ProfessionalDataTable> {
  String _searchQuery = '';
  final Map<String, String?> _selectedFilters = {};
  int _currentPage = 0;
  final int _rowsPerPage = 25;
  late ScrollController _horizontalScrollController;
  late ScrollController _verticalScrollController;
  final Set<String> _hiddenColumns = {};

  // Static map to persist pagination state across rebuilds
  static final Map<String, int> _pageStateCache = {};

  // Clean modern color palette
  static const _headerColor = Color(0xFF00BFA6);
  static const _headerText = Colors.white;
  static const _bodyText = Color(0xFF212121);
  static const _secondaryText = Color(0xFF757575);
  static const _borderColor = Color(0xFFE0E0E0);
  static const _hoverColor = Color(0xFFF5F5F5);
  static const _backgroundColor = Color(0xFFFAFAFA);

  /// Below this width the toolbar switches to the compact (stacked) layout
  static const double _compactBreakpoint = 600;

  List<Map<String, dynamic>> get _filteredData {
    var filtered = widget.data;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((row) {
        return widget.columns.any((column) {
          final value = row[column.key]?.toString().toLowerCase() ?? '';
          return value.contains(q);
        });
      }).toList();
    }

    // Handle sorting before other filters
    String? sortOrder;
    if (widget.filters != null) {
      for (var filter in widget.filters!) {
        if (filter.key == 'sortOrder') {
          sortOrder = _selectedFilters[filter.key];
          break;
        }
      }
    }

    // Apply sorting
    if (sortOrder != null && sortOrder != 'all') {
      if (sortOrder == 'newest') {
        filtered.sort((a, b) {
          final aMillis = a['createdAtMillis'] as int? ?? 0;
          final bMillis = b['createdAtMillis'] as int? ?? 0;
          return bMillis.compareTo(aMillis); // Descending (newest first)
        });
      } else if (sortOrder == 'oldest') {
        filtered.sort((a, b) {
          final aMillis = a['createdAtMillis'] as int? ?? 0;
          final bMillis = b['createdAtMillis'] as int? ?? 0;
          return aMillis.compareTo(bMillis); // Ascending (oldest first)
        });
      } else if (sortOrder == 'name') {
        filtered.sort((a, b) {
          final aName = (a['fullName'] ?? '').toString().toLowerCase();
          final bName = (b['fullName'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName); // Alphabetical
        });
      }
    }

    if (widget.filters != null) {
      for (var filter in widget.filters!) {
        final selectedValue = _selectedFilters[filter.key];
        if (selectedValue != null && selectedValue != 'all') {
          // Skip sortOrder as it's handled above
          if (filter.key == 'sortOrder') continue;
          
          filtered = filtered.where((row) {
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
            return row[filter.key]?.toString() == selectedValue;
          }).toList();
        }
      }
    }

    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _verticalScrollController = ScrollController();

    // Set default sort order to 'newest' if sortOrder filter exists
    if (widget.filters != null) {
      for (var filter in widget.filters!) {
        if (filter.key == 'sortOrder') {
          _selectedFilters[filter.key] = 'newest';
          break;
        }
      }
    }

    if (widget.tableKey != null && _pageStateCache.containsKey(widget.tableKey)) {
      _currentPage = _pageStateCache[widget.tableKey!]!;
    }
  }

  @override
  void dispose() {
    if (widget.tableKey != null) {
      _pageStateCache[widget.tableKey!] = _currentPage;
    }
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Compute once per build (instead of re-filtering in every getter)
    final filtered = _filteredData;
    final totalPages = filtered.isEmpty ? 1 : (filtered.length / _rowsPerPage).ceil();
    if (_currentPage >= totalPages) _currentPage = totalPages - 1;
    if (_currentPage < 0) _currentPage = 0;

    final start = _currentPage * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, filtered.length);
    final pageRows = filtered.sublist(math.min(start, filtered.length), end);

    return LayoutBuilder(
      builder: (context, outer) {
        // Parent gives a fixed height -> table fills it and scrolls inside.
        // Parent gives unbounded height (inside a scroll view / Column) -> table
        // sizes itself to its rows and the parent does the scrolling.
        final bounded = outer.hasBoundedHeight;

        final body = filtered.isEmpty
            ? _buildEmptyState()
            : Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildTable(pageRows),
                ),
              );

        return Column(
          mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToolbar(filtered.length, pageRows.length, totalPages),
            if (bounded) Expanded(child: body) else body,
          ],
        );
      },
    );
  }

  // ───────────────────────── Toolbar ─────────────────────────

  Widget _buildToolbar(int totalCount, int pageCount, int totalPages) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final compact = maxW < _compactBreakpoint;
        final hPad = compact ? 12.0 : 24.0;
        final innerW = maxW - (hPad * 2);

        final from = totalCount == 0 ? 0 : _currentPage * _rowsPerPage + 1;
        final to = _currentPage * _rowsPerPage + pageCount;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: compact ? 12 : 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search + filters + column toggle wrap onto new lines when needed
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.showSearch)
                    SizedBox(
                      width: compact
                          ? (widget.filters == null ? innerW - 50 : innerW)
                          : (innerW * 0.4).clamp(220.0, 420.0),
                      child: _buildSearchBox(),
                    ),
                  if (widget.filters != null)
                    ...widget.filters!.map((filter) => SizedBox(
                          width: compact ? (innerW - 8 - 50) / 2 : 180,
                          child: _buildFilterDropdown(filter),
                        )),
                  _buildColumnToggle(),
                ],
              ),
              SizedBox(height: compact ? 12 : 16),
              // Count + pagination wrap instead of overflowing
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                spacing: 12,
                children: [
                  Text(
                    'Showing $from-$to of $totalCount entries',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (totalPages > 1) _buildPagination(totalPages),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBox() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: widget.searchPlaceholder,
          hintMaxLines: 1,
          hintStyle: const TextStyle(
            fontSize: 14,
            color: _secondaryText,
            overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildColumnToggle() {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: 'Show/Hide Columns',
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_column, color: _secondaryText, size: 18),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: _secondaryText, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) {
        return widget.columns.where((col) => col.key != 'actions').map((column) {
          final isVisible = !_hiddenColumns.contains(column.key);
          return CheckedPopupMenuItem<String>(
            value: column.key,
            checked: isVisible,
            child: Text(column.label),
          );
        }).toList();
      },
      onSelected: (columnKey) {
        setState(() {
          if (_hiddenColumns.contains(columnKey)) {
            _hiddenColumns.remove(columnKey);
          } else {
            _hiddenColumns.add(columnKey);
          }
        });
      },
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
          isExpanded: true,
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
              child: Text('All ${filter.label}', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            ...filter.options.map((option) {
              return DropdownMenuItem(
                value: option.value,
                child: Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              );
            }),
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

  Widget _buildPagination(int totalPages) {
    Widget navButton(IconData icon, bool enabled, VoidCallback onTap) {
      return Material(
        color: enabled ? Colors.white : _backgroundColor,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 20, color: enabled ? _bodyText : _secondaryText),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        navButton(Icons.chevron_left, _currentPage > 0, () => setState(() => _currentPage--)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Page ${_currentPage + 1} of $totalPages',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _bodyText,
            ),
          ),
        ),
        navButton(Icons.chevron_right, _currentPage < totalPages - 1,
            () => setState(() => _currentPage++)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No data found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _secondaryText),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search or filters',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _secondaryText),
            ),
            if (_searchQuery.isNotEmpty ||
                _selectedFilters.values.any((v) => v != null && v != 'all'))
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
      ),
    );
  }

  // ───────────────────────── Table ─────────────────────────

  /// Minimum comfortable width of a column. `DataTableColumn.width` wins,
  /// otherwise it's derived from `flex`.
  double _minWidthFor(DataTableColumn c) {
    if (c.width != null) return c.width!;
    return (110.0 * c.flex).clamp(100.0, 260.0);
  }

  Widget _buildTable(List<Map<String, dynamic>> rows) {
    final visibleColumns =
        widget.columns.where((col) => !_hiddenColumns.contains(col.key)).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final minTotal = visibleColumns.fold<double>(0, (s, c) => s + _minWidthFor(c));

        // Wide screen  -> columns stretch proportionally to fill the width
        // Narrow screen -> columns keep their min width and the table scrolls sideways
        final contentWidth = math.max(available, minTotal);
        final scale = contentWidth / (minTotal == 0 ? 1 : minTotal);
        double widthOf(DataTableColumn c) => _minWidthFor(c) * scale;

        final bounded = constraints.hasBoundedHeight;

        Widget buildRow(int index) {
          final row = rows[index];
          final isEven = index % 2 == 0;

          return InkWell(
            onTap: widget.onRowTap != null ? () => widget.onRowTap!(row) : null,
            hoverColor: _hoverColor,
            child: Container(
              decoration: BoxDecoration(
                color: isEven ? Colors.white : _backgroundColor,
                border: const Border(
                  bottom: BorderSide(color: _borderColor, width: 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: visibleColumns.map((column) {
                  final cellWidget = column.builder != null
                      ? column.builder!(row)
                      : Text(
                          row[column.key]?.toString() ?? '-',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _bodyText,
                            fontWeight: FontWeight.w400,
                          ),
                        );

                  return SizedBox(
                    width: widthOf(column),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: cellWidget,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        }

        return Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: minTotal > available,
          notificationPredicate: (n) => n.depth == 0,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              // Only force a height when the parent actually gave us one
              height: bounded ? constraints.maxHeight : null,
              child: Column(
                mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    color: _headerColor,
                    child: Row(
                      children: visibleColumns.map((column) {
                        return SizedBox(
                          width: widthOf(column),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFF00AB94), width: 2),
                              ),
                            ),
                            child: Text(
                              column.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

                  // Rows
                  if (bounded)
                    Expanded(
                      child: ListView.builder(
                        controller: _verticalScrollController,
                        padding: EdgeInsets.only(bottom: widget.listBottomPadding),
                        itemCount: rows.length,
                        itemBuilder: (context, index) => buildRow(index),
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.only(bottom: widget.listBottomPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(rows.length, buildRow),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Column definition
class DataTableColumn {
  final String key;
  final String label;

  /// Minimum width in px. If omitted it's derived from [flex] (flex * 110).
  /// On wide screens columns stretch to fill; on phones the table scrolls sideways.
  final double? width;
  final int flex;
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