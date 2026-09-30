/// Test CSV parser to verify correct parsing of quoted fields
/// Run with: dart test_csv_parser.dart

void main() {
  // Actual CSV line from your file
  final testLine = '922030000265,Ankunda Costance,045993,Business loan,,Individual,Individual membership,,,Main Branch,0,No,,Claire Katushabe,Months,6,"November 11, 2025","November 10, 2025","May 10, 2026","900,000.00","78,750.00","April 10, 2026",0.00,"4,500.00","11,250.00","900,000.00", 172 ';
  
  print('🧪 Testing CSV Parser\n');
  print('Original line:');
  print(testLine);
  print('\n' + '─' * 80 + '\n');
  
  // WRONG WAY (naive split)
  final wrongSplit = testLine.split(',');
  print('❌ WRONG: Naive split by comma');
  print('   Column count: ${wrongSplit.length}');
  print('   Column 19 (should be Total Loan): "${wrongSplit[19]}"');
  print('   Result: WRONG VALUE!\n');
  
  // RIGHT WAY (quote-respecting)
  final rightSplit = parseCsvLine(testLine);
  print('✅ RIGHT: Quote-respecting parser');
  print('   Column count: ${rightSplit.length}');
  print('   Column 19 (Total Loan Amount): "${rightSplit[19]}"');
  print('   Parsed amount: ${parseAmount(rightSplit[19])}');
  print('   Result: CORRECT!\n');
  
  print('─' * 80);
  print('\n📊 All parsed columns:');
  for (int i = 0; i < rightSplit.length && i < 27; i++) {
    final labels = [
      'Account Number', 'Client Name', 'Reference Number', 'Loan Product', 'Group',
      'Member Type', 'MembershipPolicy', 'Gender', 'Age', 'Branch',
      'Dependents', 'Disability', 'ImpairmentType', 'Loan Officer',
      'Tenure Type', 'Tenure', 'Creation Date', 'Disbursement Date',
      'Expiry Date', 'Total Loan Amount', 'Total Interest Amount', 'Due Date',
      'Outstanding Charges', 'Outstanding Principal', 'Outstanding Interest',
      'Original Disbursed', 'Overdue Days'
    ];
    
    print('   [$i] ${labels[i].padRight(25)} = "${rightSplit[i]}"');
  }
}

List<String> parseCsvLine(String line) {
  final List<String> fields = [];
  final buffer = StringBuffer();
  bool inQuotes = false;

  for (int i = 0; i < line.length; i++) {
    final char = line[i];

    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }

  // Add the last field
  fields.add(buffer.toString());

  return fields;
}

double parseAmount(String value) {
  if (value.isEmpty) return 0.0;
  try {
    return double.parse(value.replaceAll(',', '').replaceAll('"', '').trim());
  } catch (e) {
    return 0.0;
  }
}
