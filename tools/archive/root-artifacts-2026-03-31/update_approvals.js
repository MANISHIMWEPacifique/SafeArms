const fs = require('fs');

let content = fs.readFileSync('frontend/lib/screens/workflows/approvals_portal_screen.dart', 'utf-8');

if (!content.includes('expandable_report_card.dart')) {
    content = content.replace("import '../../providers/approvals_provider.dart';", "import '../../providers/approvals_provider.dart';\nimport '../../widgets/expandable_report_card.dart';");
}

function replaceMethod(funcStart, newBody) {
    const startIndex = content.indexOf(funcStart);
    if (startIndex === -1) return;
    
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
    const newContent = funcStart + " {" + newBody + "\n  }";
    content = content.substring(0, startIndex) + newContent + content.substring(endIndex);
}

const lossStart = "Widget _buildLossReportsTab(ApprovalsProvider provider)";
const lossBody = `
    return Column(
      children: [
        _buildFilterBar(provider, 'loss'),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.pendingLossReports.length,
            itemBuilder: (context, index) {
              final report = provider.pendingLossReports[index];
              return ExpandableReportCard(
                reportId: 'LOSS-${"$"}{report['loss_id'] ?? 'N/A'}',
                status: report['status'] ?? 'pending',
                primaryCodeLabel: 'FIREARM',
                primaryCodeValue: report['serial_number'] ?? 'N/A',
                dateReported: report['created_at'] != null ? DateTime.parse(report['created_at']) : DateTime.now(),
                location: report['loss_location'],
                reportingUnit: report['unit_name'],
                circumstancesLabel: 'CIRCUMSTANCES',
                circumstances: report['circumstances'] ?? 'N/A',
                severityColor: const Color(0xFFF59E0B),
                onStatusChanged: (newStatus) {
                  provider.updateRequestStatus(report['loss_id'], 'loss', newStatus);
                },
                detailsWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Officer Info', "\${report['officer_rank'] ?? ''} \${report['officer_name'] ?? ''} (\${report['service_number'] ?? 'N/A'})"),
                    _buildDetailRow('Firearm Model', "\${report['manufacturer'] ?? ''} \${report['model'] ?? ''}"),
                    _buildDetailRow('Caliber', report['caliber'] ?? 'N/A'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );`;

const destStart = "Widget _buildDestructionTab(ApprovalsProvider provider)";
const destBody = `
    return Column(
      children: [
        _buildFilterBar(provider, 'destruction'),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.pendingDestructionRequests.length,
            itemBuilder: (context, index) {
              final req = provider.pendingDestructionRequests[index];
              return ExpandableReportCard(
                reportId: 'DEST-${"$"}{req['destruction_id'] ?? 'N/A'}',
                status: req['status'] ?? 'pending',
                primaryCodeLabel: 'FIREARM',
                primaryCodeValue: req['serial_number'] ?? 'N/A',
                dateReported: req['created_at'] != null ? DateTime.parse(req['created_at']) : DateTime.now(),
                location: req['condition_description'],
                reportingUnit: req['unit_name'],
                circumstancesLabel: 'REASON',
                circumstances: req['destruction_reason'] ?? 'N/A',
                severityColor: const Color(0xFFEF4444),
                onStatusChanged: (newStatus) {
                  provider.updateRequestStatus(req['destruction_id'], 'destruction', newStatus);
                },
                detailsWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Condition', req['condition_description'] ?? 'N/A'),
                    _buildDetailRow('Firearm Model', "\${req['manufacturer'] ?? ''} \${req['model'] ?? ''}"),
                    _buildDetailRow('Caliber', req['caliber'] ?? 'N/A'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );`;

const procStart = "Widget _buildProcurementTab(ApprovalsProvider provider)";
const procBody = `
    return Column(
      children: [
        _buildFilterBar(provider, 'procurement'),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.pendingProcurementRequests.length,
            itemBuilder: (context, index) {
              final req = provider.pendingProcurementRequests[index];
              return ExpandableReportCard(
                reportId: 'PROC-${"$"}{req['procurement_id'] ?? 'N/A'}',
                status: req['status'] ?? 'pending',
                primaryCodeLabel: 'TYPE',
                primaryCodeValue: req['firearm_type'] ?? 'N/A',
                dateReported: req['created_at'] != null ? DateTime.parse(req['created_at']) : DateTime.now(),
                location: 'Qty: ${"$"}{req['quantity'] ?? 'N/A'}',
                reportingUnit: req['unit_name'],
                circumstancesLabel: 'JUSTIFICATION',
                circumstances: req['justification'] ?? 'N/A',
                severityColor: const Color(0xFF3B82F6),
                onStatusChanged: (newStatus) {
                  provider.updateRequestStatus(req['procurement_id'], 'procurement', newStatus);
                },
                detailsWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Quantity Requested', req['quantity']?.toString() ?? 'N/A'),
                    _buildDetailRow('Priority', req['priority'] ?? 'Standard'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );`;

replaceMethod(lossStart, lossBody);
replaceMethod(destStart, destBody);
replaceMethod(procStart, procBody);

fs.writeFileSync('frontend/lib/screens/workflows/approvals_portal_screen.dart', content);
console.log("Done updating approvals portal screen");
