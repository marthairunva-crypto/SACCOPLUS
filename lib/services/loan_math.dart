// lib/services/loan_math.dart
//
// ONE place that decides what a loan's balances and arrears are.
//   paid  = legacy paid (before the new system) + repayments recorded here + waived interest
//   owed  = principal + interest + charges
//   arrears = (scheduled instalments already due) - paid, never more than what is outstanding
//
// Migrated loans: the old system's balances were imported but its repayment history was not.
// We keep the difference on the loan as legacyPrincipalPaid / legacyInterestPaid so the
// ledger and the balances agree and arrears stop being inflated.
//
// Interest is ALWAYS derived from the loan terms (amount, rate, tenure, method).
// The stored interestAmount is only a fallback when the terms are incomplete.

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

class LoanSnapshot {
  final double pPaid, iPaid, cPaid;
  final double pOut, iOut, cOut, totalOut;
  final double expectedToDate, arrears;
  final int installmentsDue, dpd;

  const LoanSnapshot({
    required this.pPaid,
    required this.iPaid,
    required this.cPaid,
    required this.pOut,
    required this.iOut,
    required this.cOut,
    required this.totalOut,
    required this.expectedToDate,
    required this.arrears,
    required this.installmentsDue,
    required this.dpd,
  });

  double get totalPaid => pPaid + iPaid + cPaid;
}

enum PlanKind { ok, refresh, migrate, review }

class LoanPlan {
  final PlanKind kind;
  final double legacyP, legacyI;
  final LoanSnapshot after;
  final String note;

  const LoanPlan({
    required this.kind,
    required this.legacyP,
    required this.legacyI,
    required this.after,
    this.note = '',
  });
}

class LoanMath {
  static const activeStatuses = ['disbursed', 'active', 'overdue'];

  // ── helpers ────────────────────────────────────────────────────────────────
  static double d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}'.replaceAll(',', '').trim()) ?? 0;
  }

  static double _pos(double v) => v > 0 ? v : 0.0;

  static bool isActive(Map<String, dynamic> loan) =>
      activeStatuses.contains((loan['status'] ?? '').toString().toLowerCase());

  static DateTime? asDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static double principalOf(Map<String, dynamic> l) =>
      d(l['loanAmount'] ?? l['amount']);

  static int tenureOf(Map<String, dynamic> l) =>
      d(l['duration'] ?? l['tenure'] ?? l['loanTenure']).round();

  static String methodOf(Map<String, dynamic> l) {
    final m = (l['interestMethod'] ?? 'flat').toString().toLowerCase();
    return const ['flat', 'declining', 'simple'].contains(m) ? m : 'flat';
  }

  /// Total interest for the whole loan. Rate is per period (month/week/day).
  static double totalInterest({
    required double principal,
    required double ratePct,
    required int months,
    String method = 'flat',
  }) {
    final rate = ratePct / 100;
    if (principal <= 0 || months <= 0 || rate <= 0) return 0;
    if (method == 'declining') {
      final f = math.pow(1 + rate, months).toDouble();
      final emi = principal * rate * f / (f - 1);
      return emi * months - principal;
    }
    return principal * rate * months; // flat / simple
  }

  /// Terms win over stored values. Stored interest is only a fallback.
  static double interestOf(Map<String, dynamic> l) {
    final calc = totalInterest(
      principal: principalOf(l),
      ratePct: d(l['interestRate']),
      months: tenureOf(l),
      method: methodOf(l),
    );
    if (calc > 0) return calc;
    return d(l['interestAmount'] ?? l['interest']);
  }

  static DateTime _addMonths(DateTime x, int m) {
    final y = x.year + (x.month - 1 + m) ~/ 12;
    final mo = (x.month - 1 + m) % 12 + 1;
    final last = DateTime(y, mo + 1, 0).day;
    return DateTime(y, mo, x.day > last ? last : x.day);
  }

  /// Due date of instalment [n] (1-based).
  static DateTime dueDate(DateTime start, int n, String freq) {
    switch (freq.toLowerCase()) {
      case 'daily':
        return start.add(Duration(days: n));
      case 'weekly':
        return start.add(Duration(days: 7 * n));
      default:
        return _addMonths(start, n);
    }
  }

  // ── normalising (shared by every screen) ───────────────────────────────────

  /// Same field fallbacks and legacy-paid maths as the Correction screen.
  static Map<String, dynamic> normalise(
      Map<String, dynamic> loan, List<Map<String, dynamic>> reps) {
    final principal = principalOf(loan);
    final tenure = tenureOf(loan);
    final interest = interestOf(loan);

    var inst = d(loan['installment'] ?? loan['monthlyInstallment']);
    if (inst <= 0 && tenure > 0) {
      inst = ((principal + interest) / tenure).roundToDouble();
    }

    double lp = 0, li = 0;
    for (final r in reps) {
      lp += d(r['principalAmount']);
      li += d(r['interestAmount']);
    }

    double legacyP = 0, legacyI = 0;
    if (loan['legacyAdjusted'] == true) {
      legacyP = d(loan['legacyPrincipalPaid']);
      legacyI = d(loan['legacyInterestPaid']);
    } else if (loan['principalOutstanding'] != null &&
        loan['interestOutstanding'] != null) {
      // Not saved from the Correction screen yet: derive from the stored true balances.
      legacyP = _pos(principal - d(loan['principalOutstanding']) - lp);
      legacyI = _pos(interest - d(loan['interestOutstanding']) - li);
    }

    return {
      ...loan,
      'loanAmount': principal,
      'amount': principal,
      'duration': tenure,
      'interestMethod': methodOf(loan),
      'interestAmount': interest,
      'installment': inst,
      'legacyPrincipalPaid': legacyP,
      'legacyInterestPaid': legacyI,
    };
  }

  /// One call for any screen: normalised loan + snapshot.
  static ({Map<String, dynamic> calc, LoanSnapshot snap}) computeFor(
      Map<String, dynamic> loan, List<Map<String, dynamic>> reps) {
    final calc = normalise(loan, reps);
    return (calc: calc, snap: compute(calc, reps));
  }

  // ── core calculation ───────────────────────────────────────────────────────
  static LoanSnapshot compute(
    Map<String, dynamic> loan,
    List<Map<String, dynamic>> reps, {
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final todayD = DateTime(now.year, now.month, now.day);

    final principal = principalOf(loan);
    final interest = interestOf(loan);
    final charges = d(loan['charges']);
    final waived = d(loan['interestWaived']);
    final n = tenureOf(loan);
    final freq = (loan['paymentFrequency'] ?? 'monthly').toString();

    double pPaid = d(loan['legacyPrincipalPaid']);
    double iPaid = d(loan['legacyInterestPaid']);
    double cPaid = 0;
    for (final r in reps) {
      pPaid += d(r['principalAmount']);
      iPaid += d(r['interestAmount']);
      cPaid += d(r['chargesAmount']);
    }

    final payable = principal + interest + charges;
    final totalPaid = pPaid + iPaid + cPaid + waived;
    
    // For manually corrected loans, use stored outstanding balances
    // For non-corrected loans, calculate from scratch
    double pOut, iOut, cOut, totalOut;
    
    if (loan['legacyAdjusted'] == true) {
      // Use stored balances for corrected loans
      pOut = d(loan['principalOutstanding']);
      iOut = d(loan['interestOutstanding']);
      cOut = d(loan['chargesOutstanding']);
      totalOut = pOut + iOut + cOut;
    } else {
      // Calculate from scratch for non-corrected loans
      pOut = _pos(principal - pPaid);
      iOut = _pos(interest - iPaid - waived);
      cOut = _pos(charges - cPaid);
      totalOut = _pos(payable - totalPaid);
    }

    // Walk the schedule against everything paid.
    final start = asDate(loan['disbursementDate'] ?? loan['disbursedAt']);
    double expected = 0;
    int due = 0;
    int dpd = 0;
    if (start != null && n > 0 && payable > 0) {
      var per = d(loan['installment'] ?? loan['monthlyInstallment']);
      if (per <= 0) per = (payable / n).roundToDouble();
      var oldestFound = false;
      for (var i = 1; i <= n; i++) {
        final cum = i == n ? payable : math.min(per * i, payable);
        final dd = dueDate(start, i, freq);
        if (dd.isBefore(todayD)) {
          expected = cum;
          due = i;
          if (!oldestFound && totalPaid < cum - 0.5) {
            oldestFound = true;
            dpd = todayD.difference(DateTime(dd.year, dd.month, dd.day)).inDays;
          }
        }
      }
    }

    final arrears = math.min(_pos(expected - totalPaid), totalOut);

    return LoanSnapshot(
      pPaid: pPaid,
      iPaid: iPaid,
      cPaid: cPaid,
      pOut: pOut,
      iOut: iOut,
      cOut: cOut,
      totalOut: totalOut,
      expectedToDate: expected,
      arrears: arrears,
      installmentsDue: due,
      dpd: dpd,
    );
  }

  // ── migration planning ─────────────────────────────────────────────────────
  static bool _matchesStored(Map<String, dynamic> loan, LoanSnapshot s) =>
      (d(loan['arrears']) - s.arrears).abs() < 1 &&
      (d(loan['principalOutstanding']) - s.pOut).abs() < 1 &&
      (d(loan['interestOutstanding']) - s.iOut).abs() < 1;

  /// Decides what (if anything) must change on a loan. Pure, no writes.
  static LoanPlan plan(Map<String, dynamic> loan, List<Map<String, dynamic>> reps) {
    double lp = 0, li = 0;
    for (final r in reps) {
      lp += d(r['principalAmount']);
      li += d(r['interestAmount']);
    }

    // Already reconciled: just keep derived fields fresh.
    if (loan['legacyAdjusted'] == true) {
      final after = compute(loan, reps);
      return LoanPlan(
        kind: _matchesStored(loan, after) ? PlanKind.ok : PlanKind.refresh,
        legacyP: d(loan['legacyPrincipalPaid']),
        legacyI: d(loan['legacyInterestPaid']),
        after: after,
      );
    }

    final hasBalances =
        loan['principalOutstanding'] != null && loan['interestOutstanding'] != null;
    if (!hasBalances) {
      final after = compute(loan, reps);
      return LoanPlan(
        kind: _matchesStored(loan, after) ? PlanKind.ok : PlanKind.refresh,
        legacyP: 0,
        legacyI: 0,
        after: after,
        note: 'No stored balances, calculated from recorded payments only.',
      );
    }

    final gapP = principalOf(loan) - d(loan['principalOutstanding']) - lp;
    final gapI = interestOf(loan) - d(loan['interestOutstanding']) - li;

    if (gapP < -0.5 || gapI < -0.5) {
      return LoanPlan(
        kind: PlanKind.review,
        legacyP: 0,
        legacyI: 0,
        after: compute(loan, reps),
        note: 'Payments on record (P ${lp.round()} / I ${li.round()}) are more than '
            'the stored balance allows. Check for duplicate payments or old-system overlap, '
            'then fix it on the Correct Loan Data screen.',
      );
    }

    final legacyP = _pos(gapP);
    final legacyI = _pos(gapI);
    final withLegacy = <String, dynamic>{
      ...loan,
      'legacyPrincipalPaid': legacyP,
      'legacyInterestPaid': legacyI,
    };
    final after = compute(withLegacy, reps);
    final needsMigration = legacyP > 0.5 || legacyI > 0.5;
    return LoanPlan(
      kind: needsMigration
          ? PlanKind.migrate
          : (_matchesStored(loan, after) ? PlanKind.ok : PlanKind.refresh),
      legacyP: legacyP,
      legacyI: legacyI,
      after: after,
    );
  }

  /// The loan-doc fields that are DERIVED (never typed by hand).
  /// For manually corrected loans (legacyAdjusted=true), we update paid amounts and arrears,
  /// but we update outstanding balances by subtracting new payments from existing balances
  /// rather than recalculating from scratch.
  static Map<String, dynamic> derived(Map<String, dynamic> loan, LoanSnapshot s) {
    final m = <String, dynamic>{
      'principalPaid': s.pPaid,
      'interestPaid': s.iPaid,
      'chargesPaid': s.cPaid,
      'totalRepaid': s.totalPaid,
      'daysInArrears': s.dpd,
      'arrearsUpdatedAt': FieldValue.serverTimestamp(),
    };
    
    // For manually corrected loans, calculate outstanding as: stored - new_payments
    // This preserves manual corrections while updating for new payments
    if (loan['legacyAdjusted'] == true) {
      // Get the previously stored outstanding balances
      final prevPOut = d(loan['principalOutstanding']);
      final prevIOut = d(loan['interestOutstanding']);
      final prevCOut = d(loan['chargesOutstanding'] ?? 0);
      
      // Get previously stored paid amounts
      final prevPPaid = d(loan['principalPaid']);
      final prevIPaid = d(loan['interestPaid']);
      final prevCPaid = d(loan['chargesPaid']);
      
      // Calculate how much MORE was paid since last update
      final newPPaid = math.max(0, s.pPaid - prevPPaid);
      final newIPaid = math.max(0, s.iPaid - prevIPaid);
      final newCPaid = math.max(0, s.cPaid - prevCPaid);
      
      // Deduct new payments from stored outstanding
      m['principalOutstanding'] = math.max(0, prevPOut - newPPaid);
      m['interestOutstanding'] = math.max(0, prevIOut - newIPaid);
      m['chargesOutstanding'] = math.max(0, prevCOut - newCPaid);
      m['totalOutstanding'] = d(m['principalOutstanding']) + d(m['interestOutstanding']) + d(m['chargesOutstanding']);
      m['remainingBalance'] = m['totalOutstanding'];
    } else {
      // For non-corrected loans, use calculated values
      m['principalOutstanding'] = s.pOut;
      m['interestOutstanding'] = s.iOut;
      m['chargesOutstanding'] = s.cOut;
      m['totalOutstanding'] = s.totalOut;
      m['remainingBalance'] = s.totalOut;
    }
    
    m['arrears'] = s.arrears;
    
    final st = (loan['status'] ?? '').toString().toLowerCase();
    if (isActive(loan)) {
      if (s.arrears > 0.5) {
        m['status'] = 'overdue';
      } else if (st == 'overdue') {
        m['status'] = 'disbursed';
      }
    }
    return m;
  }

  // ── Firestore helpers ──────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> repaymentsFor(String loanId) async {
    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.repaymentsCol)
        .where('loanId', isEqualTo: loanId)
        .get();
    return snap.docs.map((e) => e.data()).toList();
  }

  /// Safe to call anywhere (after payment, undo, opening a loan, daily job).
  /// It will NEVER overwrite true balances of a migrated loan that has not been
  /// reconciled yet: those are skipped until you run "Reconcile all loans".
  /// For manually corrected loans (legacyAdjusted=true), it updates outstanding
  /// by deducting new payments from stored balances rather than recalculating from scratch.
  static Future<LoanSnapshot?> recalculate(String loanId) async {
    final ref = FirebaseFirestore.instance
        .collection(AppConstants.loansCol)
        .doc(loanId);
    final snap = await ref.get();
    if (!snap.exists) return null;
    final loan = <String, dynamic>{'id': snap.id, ...snap.data()!};
    final reps = await repaymentsFor(loanId);
    final p = plan(loan, reps);
    if (p.kind == PlanKind.migrate || p.kind == PlanKind.review) return null;
    if (p.kind == PlanKind.refresh) {
      await ref.update(derived(loan, p.after));
    }
    return p.after;
  }
}