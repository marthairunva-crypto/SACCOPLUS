import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'audit_service.dart';

/// Service for calculating and applying interest to savings and fixed deposits
class InterestService {
  static final _db = FirebaseFirestore.instance;

  /// Calculate and apply monthly interest to all savings accounts
  /// Call this method monthly (e.g., on the 1st of each month)
  static Future<void> calculateMonthlySavingsInterest() async {
    try {
      print('Starting monthly savings interest calculation...');
      
      await FirebaseService.calculateSavingsInterest();
      
      // Log the interest calculation
      await AuditService.log(
        action: 'INTEREST_CALCULATED',
        description: 'Monthly savings interest calculated and applied to all accounts',
        meta: {'type': 'savings', 'period': 'monthly'},
      );
      
      print('Monthly savings interest calculation completed');
    } catch (e) {
      print('Error calculating monthly savings interest: $e');
      
      // Log the error
      await AuditService.log(
        action: 'INTEREST_CALCULATION_ERROR',
        description: 'Failed to calculate monthly savings interest: $e',
        meta: {'type': 'savings', 'error': e.toString()},
      );
    }
  }

  /// Process matured fixed deposits
  /// Call this method daily to check for matured FDs
  static Future<void> processMaturedFixedDeposits() async {
    try {
      print('Processing matured fixed deposits...');
      
      await FirebaseService.processMaturedFDs();
      
      print('Matured fixed deposits processing completed');
    } catch (e) {
      print('Error processing matured fixed deposits: $e');
      
      // Log the error
      await AuditService.log(
        action: 'FD_MATURITY_PROCESSING_ERROR',
        description: 'Failed to process matured fixed deposits: $e',
        meta: {'error': e.toString()},
      );
    }
  }

  /// Calculate compound interest for fixed deposits
  static double calculateCompoundInterest({
    required double principal,
    required double annualRate,
    required int termMonths,
    int compoundingFrequency = 12, // Monthly compounding by default
  }) {
    final rate = annualRate / 100;
    final time = termMonths / 12.0;
    final amount = principal * pow(1 + (rate / compoundingFrequency), compoundingFrequency * time);
    return amount - principal; // Return only the interest
  }

  /// Calculate simple interest
  static double calculateSimpleInterest({
    required double principal,
    required double annualRate,
    required int termMonths,
  }) {
    final rate = annualRate / 100;
    final time = termMonths / 12.0;
    return principal * rate * time;
  }

  /// Get interest rate for different savings types
  static double getSavingsInterestRate(String savingsType) {
    switch (savingsType) {
      case 'Voluntary':
        return 2.0; // 2% per annum
      case 'Compulsory':
        return 1.5; // 1.5% per annum
      case 'Fixed Deposit':
        return 5.0; // 5% per annum (handled separately)
      default:
        return 1.0; // 1% per annum default
    }
  }

  /// Schedule automatic interest calculations (for future implementation)
  /// This would typically be handled by a server-side cron job or cloud function
  static void scheduleInterestCalculations() {
    // This is a placeholder for future implementation
    // In a production app, you would use:
    // - Firebase Cloud Functions with scheduled triggers
    // - Server-side cron jobs
    // - Background tasks in your backend
    
    print('Interest calculation scheduling would be implemented here');
    print('Recommended: Use Firebase Cloud Functions with cron triggers');
    print('Example: functions.pubsub.schedule("0 0 1 * *") for monthly on 1st');
  }
}

// Helper function for power calculation (since dart:math might not be available)
double pow(double base, double exponent) {
  if (exponent == 0) return 1;
  if (exponent == 1) return base;
  
  double result = 1;
  for (int i = 0; i < exponent.abs(); i++) {
    result *= base;
  }
  
  return exponent < 0 ? 1 / result : result;
}