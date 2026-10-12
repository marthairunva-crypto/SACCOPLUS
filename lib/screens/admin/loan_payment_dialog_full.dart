// PASTE THIS METHOD TO REPLACE _showRecordPaymentDialog in loan_details_screen.dart

Future<void> _showRecordPaymentDialog() async {
  final principalCtrl = TextEditingController();
  final interestCtrl = TextEditingController();
  final chargesCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final phoneNumberCtrl = TextEditingController();
  
  DateTime paymentDate = DateTime.now();
  String paymentMethod = 'Cash';
  String? telecomProvider;
  String? verifiedAccountName;
  bool isVerifying = false;
  
  final principalOutstanding = (_loanData!['principalOutstanding'] ?? 0).toDouble();
  final interestOutstanding = (_loanData!['interestOutstanding'] ?? 0).toDouble();
  
  principalCtrl.text = '0';
  interestCtrl.text = '0';
  chargesCtrl.text = '0';
  amountCtrl.text = '0';
  
  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void updateTotal() {
          final principal = double.tryParse(principalCtrl.text) ?? 0;
          final interest = double.tryParse(interestCtrl.text) ?? 0;
          final charges = double.tryParse(chargesCtrl.text) ?? 0;
          amountCtrl.text = (principal + interest + charges).round().toString();
        }
        
        Future<void> verifyPhoneNumber() async {
          if (phoneNumberCtrl.text.trim().isEmpty || telecomProvider == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter phone number and select provider')),
            );
            return;
          }
          
          setState(() {
            isVerifying = true;
            verifiedAccountName = null;
          });
          
          try {
            final result = await TellerService.verifyMobileMoneyAccount(
              phoneNumber: phoneNumberCtrl.text.trim(),
              provider: telecomProvider!,
            );
            
            setState(() {
              isVerifying = false;
              if (result['success'] == true) {
                verifiedAccountName = result['accountName'] ?? result['full_name'];
              }
            });
            
            if (result['success'] != true) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'] ?? 'Verification failed'), backgroundColor: Colors.red),
                );
              }
            }
          } catch (e) {
            setState(() => isVerifying = false);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            }
          }
        }
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.payment, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Record Loan Payment', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('Outstanding: Principal UGX ${_currencyFormat.format(principalOutstanding.round())} | Interest UGX ${_currencyFormat.format(interestOutstanding.round())}', 
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Payment Date
                        Text('Payment Date', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: paymentDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => paymentDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 18),
                                const SizedBox(width: 12),
                                Text(DateFormat('MMM dd, yyyy').format(paymentDate)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Payment Method
                        Text('Payment Method', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: paymentMethod,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'Mobile Money', child: Text('Mobile Money')),
                            DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                            DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                          ],
                          onChanged: (value) {
                            setState(() => paymentMethod = value ?? 'Cash');
                          },
                        ),
                        
                        // Mobile Money Fields
                        if (paymentMethod == 'Mobile Money') ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Telecom Provider', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: telecomProvider,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        hintText: 'Select Provider',
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'MTN', child: Text('MTN Mobile Money')),
                                        DropdownMenuItem(value: 'Airtel', child: Text('Airtel Money')),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          telecomProvider = value;
                                          verifiedAccountName = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Customer Phone Number', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                  if (verifiedAccountName != null)
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          phoneNumberCtrl.clear();
                                          verifiedAccountName = null;
                                        });
                                      },
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: Text('New Customer', style: GoogleFonts.inter(fontSize: 12)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: phoneNumberCtrl,
                                      keyboardType: TextInputType.phone,
                                      enabled: verifiedAccountName == null,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        hintText: '256700000000',
                                        contentPadding: const EdgeInsets.all(12),
                                        filled: verifiedAccountName != null,
                                        fillColor: Colors.green.shade50,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (verifiedAccountName == null)
                                    ElevatedButton(
                                      onPressed: isVerifying ? null : verifyPhoneNumber,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      ),
                                      child: isVerifying 
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Text('VERIFY'),
                                    ),
                                ],
                              ),
                              if (verifiedAccountName != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '✓ Verified: $verifiedAccountName',
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade900),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        
                        // Amount Fields
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Principal Amount', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: principalCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.all(12),
                                      hintText: '0',
                                    ),
                                    onChanged: (_) => updateTotal(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Interest Amount', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: interestCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.all(12),
                                      hintText: '0',
                                    ),
                                    onChanged: (_) => updateTotal(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Charges Amount', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: chargesCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.all(12),
                                      hintText: '0',
                                    ),
                                    onChanged: (_) => updateTotal(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Amount', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: amountCtrl,
                                    readOnly: true,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.all(12),
                                      filled: true,
                                      fillColor: Colors.green.shade50,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final principal = double.tryParse(principalCtrl.text) ?? 0;
                          final interest = double.tryParse(interestCtrl.text) ?? 0;
                          final charges = double.tryParse(chargesCtrl.text) ?? 0;
                          final total = principal + interest + charges;
                          
                          if (total <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter at least one amount'), backgroundColor: Colors.orange),
                            );
                            return;
                          }
                          
                          if (paymentMethod == 'Mobile Money' && verifiedAccountName == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please verify phone number first'), backgroundColor: Colors.orange),
                            );
                            return;
                          }
                          
                          try {
                            String? transactionId;
                            
                            // Process mobile money payment
                            if (paymentMethod == 'Mobile Money') {
                              Navigator.pop(context);
                              
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Processing Mobile Money Payment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 16),
                                      Text('Please approve the payment on your phone...', style: GoogleFonts.inter()),
                                      const SizedBox(height: 8),
                                      Text('Amount: UGX ${_currencyFormat.format(total.round())}', 
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              );
                              
                              final paymentResult = await TellerService.processMobileMoneyPayment(
                                phoneNumber: phoneNumberCtrl.text.trim(),
                                amount: total,
                                provider: telecomProvider!,
                                narration: 'Loan repayment for ${_loanData!['memberName']}',
                              );
                              
                              if (context.mounted) Navigator.pop(context);
                              
                              if (paymentResult['success'] != true) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(paymentResult['message'] ?? 'Payment failed'), backgroundColor: Colors.red),
                                  );
                                }
                                return;
                              }
                              
                              transactionId = paymentResult['transactionId'];
                            }
                            
                            // Save payment to Firebase
                            final paymentData = {
                              'loanId': widget.loanId,
                              'paymentDate': Timestamp.fromDate(paymentDate),
                              'principalAmount': principal,
                              'interestAmount': interest,
                              'chargesAmount': charges,
                              'amount': total,
                              'paymentMethod': paymentMethod,
                              'recordedBy': 'Teller',
                              'createdAt': FieldValue.serverTimestamp(),
                            };
                            
                            if (paymentMethod == 'Mobile Money') {
                              paymentData['mobileMoneyProvider'] = telecomProvider;
                              paymentData['mobileMoneyNumber'] = phoneNumberCtrl.text.trim();
                              paymentData['mobileMoneyTransactionId'] = transactionId;
                            }
                            
                            await FirebaseFirestore.instance.collection(AppConstants.repaymentsCol).add(paymentData);
                            
                            // Update loan totals
                            await FirebaseFirestore.instance.collection(AppConstants.loansCol).doc(widget.loanId).update({
                              'principalPaid': FieldValue.increment(principal),
                              'interestPaid': FieldValue.increment(interest),
                              'chargesPaid': FieldValue.increment(charges),
                              'principalOutstanding': FieldValue.increment(-principal),
                              'interestOutstanding': FieldValue.increment(-interest),
                              'chargesOutstanding': FieldValue.increment(-charges),
                              'remainingBalance': FieldValue.increment(-(principal + interest + charges)),
                              'totalOutstanding': FieldValue.increment(-(principal + interest + charges)),
                              'outstanding': FieldValue.increment(-(principal + interest + charges)),
                            });
                            
                            if (paymentMethod != 'Mobile Money' && context.mounted) {
                              Navigator.pop(context);
                            }
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✓ Payment recorded successfully!'), backgroundColor: Colors.green),
                              );
                              _loadLoanData();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('RECORD PAYMENT'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
