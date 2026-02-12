// Data Table Widget
// Reusable data table component

import 'package:flutter/material.dart';

class SafeArmsDataTable extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final bool isLoading;
  final String? emptyMessage;
  final List<double>? columnWidths;

  const SafeArmsDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.emptyMessage,
    this.columnWidths,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(
            color: Color(0xFF1E88E5),
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox, color: Color(0xFF78909C), size: 48),
              const SizedBox(height: 16),
              Text(
                emptyMessage ?? 'No data available',
                style: const TextStyle(color: Color(0xFF78909C), fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF252A3A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: List.generate(columns.length, (i) {
                return Expanded(
                  flex: columnWidths != null
                      ? (columnWidths![i] * 10).round()
                      : 1,
                  child: Text(
                    columns[i],
                    style: const TextStyle(
                      color: Color(0xFF78909C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }),
            ),
          ),
          // Rows
          ...rows.map((row) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF37404F), width: 0.5),
                  ),
                ),
                child: Row(
                  children: List.generate(row.length, (i) {
                    return Expanded(
                      flex: columnWidths != null && i < columnWidths!.length
                          ? (columnWidths![i] * 10).round()
                          : 1,
                      child: row[i],
                    );
                  }),
                ),
              )),
        ],
      ),
    );
  }
}
