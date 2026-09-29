import 'dart:convert';
import 'dart:html' as html;
import 'package:intl/intl.dart';

/// Utility class for exporting data to CSV files
class CsvExport {
  /// Export loan data to CSV
  static void exportLoans(List<Map<String, dynamic>> loans) {
    if (loans.isEmpty) {
      return;
    }

    final buffer = StringBuffer();
    
    // Header row
    buffer.writeln(
      'Loan ID,Member Name,Member Phone,Member Number,Account Number,'
      'Loan Type,Amount,Interest Amount,Total Amount,Balance,Amount Paid,'
      'Outstanding Principal,Outstanding Interest,Status,Overdue Days,'
      'Duration,Payment Frequency,Purpose,Created Date,Disbursed Date,'
      'Due Date,Approved By,Admin Notes'
    );

    // Data rows
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    for (final loan in loans) {
      final row = [
        loan['id'] ?? '',
        _escapeCsv(loan['farmerName'] ?? loan['clientName'] ?? ''),
        loan['farmerPhone'] ?? loan['phone'] ?? '',
        loan['memberNumber'] ?? '',
        loan['accountNumber'] ?? '',
        loan['loanType'] ?? loan['loanProduct'] ?? '',
        loan['amount'] ?? 0,
        loan['interestAmount'] ?? 0,
        loan['totalAmount'] ?? 0,
        loan['balance'] ?? 0,
        loan['amountPaid'] ?? 0,
        loan['outstandingPrincipal'] ?? 0,
        loan['outstandingInterest'] ?? 0,
        loan['status'] ?? '',
        loan['overdueDays'] ?? 0,
        loan['duration'] ?? loan['tenure'] ?? '',
        loan['paymentFrequency'] ?? loan['tenureType'] ?? '',
        _escapeCsv(loan['purpose'] ?? ''),
        loan['createdAt'] != null ? _formatDate(loan['createdAt'], dateFormat) : '',
        loan['disbursedAt'] != null ? _formatDate(loan['disbursedAt'], dateFormat) : '',
        loan['dueDate'] != null ? _formatDate(loan['dueDate'], dateFormat) : '',
        loan['approvedBy'] ?? loan['loanOfficer'] ?? '',
        _escapeCsv(loan['adminNotes'] ?? loan['adminNote'] ?? ''),
      ];
      buffer.writeln(row.join(','));
    }

    _downloadCsv(buffer.toString(), 'loans_report_${DateTime.now().millisecondsSinceEpoch}.csv');
  }

  /// Export member data to CSV
  static void exportMembers(List<Map<String, dynamic>> members) {
    if (members.isEmpty) {
      return;
    }

    final buffer = StringBuffer();
    
    // Header row
    buffer.writeln(
      'Member ID,Member Number,Account Number,Name,Phone,Gender,Branch,'
      'Member Type,Group,ID Status,Savings Balance,Shares Balance,'
      'Total Shares,Loan Balance,Wallet Balance,Registration Date,'
      'Created Date,Migrated From'
    );

    // Data rows
    final dateFormat = DateFormat('yyyy-MM-dd');
    for (final member in members) {
      final row = [
        member['id'] ?? member['uid'] ?? '',
        member['memberNumber'] ?? '',
        member['accountNumber'] ?? '',
        _escapeCsv(member['name'] ?? member['fullName'] ?? ''),
        member['phone'] ?? '',
        member['gender'] ?? '',
        member['branch'] ?? '',
        member['memberType'] ?? '',
        _escapeCsv(member['group'] ?? ''),
        member['idStatus'] ?? '',
        member['savingsBalance'] ?? 0,
        member['sharesBalance'] ?? 0,
        member['totalShares'] ?? 0,
        member['loanBalance'] ?? 0,
        member['walletBalance'] ?? 0,
        member['registrationDate'] != null ? _formatDate(member['registrationDate'], dateFormat) : '',
        member['createdAt'] != null ? _formatDate(member['createdAt'], dateFormat) : '',
        member['migratedFrom'] ?? '',
      ];
      buffer.writeln(row.join(','));
    }

    _downloadCsv(buffer.toString(), 'members_report_${DateTime.now().millisecondsSinceEpoch}.csv');
  }

  /// Export repayment data to CSV
  static void exportRepayments(List<Map<String, dynamic>> repayments) {
    if (repayments.isEmpty) {
      return;
    }

    final buffer = StringBuffer();
    
    // Header row
    buffer.writeln(
      'Repayment ID,Loan ID,Member ID,Member Name,Amount,Payment Method,'
      'Transaction Reference,Payment Date,Recorded By,Notes'
    );

    // Data rows
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    for (final repayment in repayments) {
      final row = [
        repayment['id'] ?? '',
        repayment['loanId'] ?? '',
        repayment['memberId'] ?? repayment['farmerId'] ?? '',
        _escapeCsv(repayment['memberName'] ?? repayment['farmerName'] ?? ''),
        repayment['amount'] ?? 0,
        repayment['paymentMethod'] ?? '',
        repayment['transactionRef'] ?? '',
        repayment['paidAt'] != null ? _formatDate(repayment['paidAt'], dateFormat) : '',
        repayment['recordedBy'] ?? '',
        _escapeCsv(repayment['notes'] ?? ''),
      ];
      buffer.writeln(row.join(','));
    }

    _downloadCsv(buffer.toString(), 'repayments_report_${DateTime.now().millisecondsSinceEpoch}.csv');
  }

  /// Escape CSV special characters
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Format Firestore timestamp to string
  static String _formatDate(dynamic timestamp, DateFormat format) {
    try {
      if (timestamp == null) return '';
      
      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else if (timestamp.runtimeType.toString().contains('Timestamp')) {
        // Handle Firestore Timestamp
        date = timestamp.toDate();
      } else {
        return '';
      }
      
      return format.format(date);
    } catch (e) {
      return '';
    }
  }

  /// Download CSV file in browser
  static void _downloadCsv(String csvContent, String filename) {
    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
