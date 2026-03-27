const fs = require('fs');

let content = fs.readFileSync('frontend/lib/screens/workflows/reports_screen.dart', 'utf-8');

// Add import
if (!content.includes('expandable_report_card.dart')) {
    content = content.replace("import '../../widgets/empty_state_widget.dart';", "import '../../widgets/empty_state_widget.dart';\nimport '../../widgets/expandable_report_card.dart';");
}

function replaceMethod(funcStart, newBody) {
    const startIndex = content.indexOf(funcStart);
    if (startIndex === -1) return;
    
    // Find the matching closing brace
    let braceCount = 0;
    let index = startIndex + funcStart.length;
    let foundInitialBrace = false;
    
    while (index < content.length) {
        if (content[index] === '{') {
            braceCount++;
            foundInitialBrace = true;
        } else if (content[index] === '}') {
            braceCount--;
        }
        
        if (foundInitialBrace && braceCount === 0) {
            break;
        }
        index++;
    }
    
    const endIndex = index + 1;
    // Note: JS doesn't have a direct equivalent to python's replace trick, so use sub-string.
    // wait, we can just replace the string between startIndex and endIndex
    const newContent = funcStart + " {" + newBody + "\n  }";
    content = content.substring(0, startIndex) + newContent + content.substring(endIndex);
}

const lossStart = "Widget _buildLossReportCard(Map<String, dynamic> report, bool isStation,\n      {bool canApprove = false, bool canDelete = false})";
const lossBody = `
    final status = report['status'] ?? 'pending';
    final createdAt = report['created_at'] != null
        ? DateTime.parse(report['created_at'])
        : DateTime.now();

    return ExpandableReportCard(
      reportId: 'LOSS-${"$"}{report['loss_id'] ?? 'N/A'}',
      status: status,
      primaryCodeLabel: 'FIREARM',
      primaryCodeValue: report['serial_number'] ?? 'N/A',
      dateReported: createdAt,
      location: report['loss_location'],
      reportingUnit: !isStation ? report['unit_name'] : null,
      circumstancesLabel: 'CIRCUMSTANCES',
      circumstances: report['circumstances'] ?? 'N/A',
      severityColor: const Color(0xFFF59E0B), // Amber for loss
      onDelete: canDelete ? () => _handleDeleteReport(report, 'loss') : null,
      onStatusChanged: canApprove ? (newStatus) => _handleReportAction(report, 'loss', newStatus) : null,
      detailsWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Status', status.toUpperCase()),
          const SizedBox(height: 8),
          const Text('Additional investigation details can go here...', style: TextStyle(color: Color(0xFF8B97AA))),
        ],
      ),
    );`;

replaceMethod(lossStart, lossBody);

const destStart = "Widget _buildDestructionCard(Map<String, dynamic> request, bool isStation,\n      {bool canApprove = false, bool canDelete = false})";
const destBody = `
    final status = request['status'] ?? 'pending';
    final createdAt = request['created_at'] != null
        ? DateTime.parse(request['created_at'])
        : DateTime.now();

    return ExpandableReportCard(
      reportId: 'DEST-${"$"}{request['destruction_id'] ?? 'N/A'}',
      status: status,
      primaryCodeLabel: 'FIREARM',
      primaryCodeValue: request['serial_number'] ?? 'N/A',
      dateReported: createdAt,
      location: request['condition_description'], // using condition as location string
      reportingUnit: !isStation ? request['unit_name'] : null,
      circumstancesLabel: 'REASON',
      circumstances: request['destruction_reason'] ?? 'N/A',
      severityColor: const Color(0xFFEF4444), // Red for destruction
      onDelete: canDelete ? () => _handleDeleteReport(request, 'destruction') : null,
      onStatusChanged: canApprove ? (newStatus) => _handleReportAction(request, 'destruction', newStatus) : null,
      detailsWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Status', status.toUpperCase()),
          if (request['condition_description'] != null)
             _buildInfoRow('Condition', request['condition_description']),
        ],
      ),
    );`;

replaceMethod(destStart, destBody);

const procStart = "Widget _buildProcurementCard(Map<String, dynamic> request, bool isStation,\n      {bool canApprove = false, bool canDelete = false})";
const procBody = `
    final status = request['status'] ?? 'pending';
    final createdAt = request['created_at'] != null
        ? DateTime.parse(request['created_at'])
        : DateTime.now();

    return ExpandableReportCard(
      reportId: 'PROC-${"$"}{request['procurement_id'] ?? 'N/A'}',
      status: status,
      primaryCodeLabel: 'TYPE',
      primaryCodeValue: request['firearm_type'] ?? 'N/A',
      dateReported: createdAt,
      location: 'Qty: ${"$"}{request['quantity'] ?? 'N/A'}',
      reportingUnit: !isStation ? request['unit_name'] : null,
      circumstancesLabel: 'JUSTIFICATION',
      circumstances: request['justification'] ?? 'N/A',
      severityColor: const Color(0xFF3B82F6), // Blue for procurement
      onDelete: canDelete ? () => _handleDeleteReport(request, 'procurement') : null,
      onStatusChanged: canApprove ? (newStatus) => _handleReportAction(request, 'procurement', newStatus) : null,
      detailsWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Status', status.toUpperCase()),
          _buildInfoRow('Quantity', request['quantity']?.toString() ?? 'N/A'),
        ],
      ),
    );`;

replaceMethod(procStart, procBody);

fs.writeFileSync('frontend/lib/screens/workflows/reports_screen.dart', content);
console.log("Done refs");
