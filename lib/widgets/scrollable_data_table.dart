import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A properly aligned, scrollable data table with consistent row heights
class ScrollableDataTable extends StatefulWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String? emptyMessage;
  final Widget? header;
  final double rowHeight;
  final double headerHeight;

  const ScrollableDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage,
    this.header,
    this.rowHeight = 52.0,
    this.headerHeight = 56.0,
  });

  @override
  State<ScrollableDataTable> createState() => _ScrollableDataTableState();
}

class _ScrollableDataTableState extends State<ScrollableDataTable> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                widget.emptyMessage ?? 'No data available',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null) widget.header!,
        Expanded(
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            child: Scrollbar(
              controller: _verticalController,
              thumbVisibility: true,
              notificationPredicate: (notification) => notification.depth == 1,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _calculateTotalWidth(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      _buildHeader(),
                      // Rows
                      Expanded(
                        child: ListView.builder(
                          controller: _verticalController,
                          itemCount: widget.rows.length,
                          itemBuilder: (context, index) {
                            return _buildRow(widget.rows[index], index);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _calculateTotalWidth() {
    double total = 0;
    for (final col in widget.columns) {
      if (col is DataColumn && col.numeric == false) {
        // Estimate width from label
        total += 150; // Default width
      } else {
        total += 120;
      }
    }
    return total.clamp(800, double.infinity);
  }

  Widget _buildHeader() {
    return Container(
      height: widget.headerHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF00BFA6),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF00AB94), width: 2),
        ),
      ),
      child: Row(
        children: widget.columns.map((column) {
          return Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: DefaultTextStyle(
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
                child: column.label,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRow(DataRow row, int index) {
    final isEven = index % 2 == 0;
    return Container(
      height: widget.rowHeight,
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFFAFAFA),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: InkWell(
        onTap: row.onSelectChanged != null ? () => row.onSelectChanged!(true) : null,
        hoverColor: const Color(0xFFF5F5F5),
        child: Row(
          children: row.cells.map((cell) {
            return Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle(
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF212121),
                    fontWeight: FontWeight.w400,
                  ),
                  child: cell.child,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
