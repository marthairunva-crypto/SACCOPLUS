/// SaccoProfile — the per-SACCO tenant configuration.
///
/// Stored in Firestore: saccoplus-saccos/{tenantId}
///
/// The SACCOPLUS platform can host unlimited SACCOs.
/// Each SACCO has its own tenantId, branding, settings, and data scope.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SaccoProfile {
  // ── Identity ──────────────────────────────────────────────────────────────
  final String tenantId;        // e.g. 'sacco_001', 'sacco_002'
  final String saccoName;       // e.g. 'Mbarara United SACCO'
  final String shortName;       // e.g. 'MUS'
  final String tagline;         // e.g. 'Banking Made Simple'
  final String registrationNo;  // official registration number

  // ── Branding ──────────────────────────────────────────────────────────────
  final String logoUrl;         // remote URL or empty (falls back to SACCOPLUS logo)
  final Color  primaryColor;    // brand colour
  final Color  accentColor;     // accent / secondary colour

  // ── Contact ───────────────────────────────────────────────────────────────
  final String phone;
  final String email;
  final String address;
  final String website;

  // ── Financial config ──────────────────────────────────────────────────────
  final String country;         // 'UG', 'KE', etc. — default MarzPay country
  final String currency;        // 'UGX', 'KES', etc.
  final int    minLoan;
  final int    maxLoan;
  final double loanRate;        // % per annum
  final double penaltyRate;     // % late payment
  final int    minSavings;
  final double savingsRate;     // % per annum
  final int    shareValue;      // UGX per share
  final int    minShares;

  // ── Status ────────────────────────────────────────────────────────────────
  final String status;          // 'active' | 'inactive' | 'suspended'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SaccoProfile({
    required this.tenantId,
    required this.saccoName,
    this.shortName    = '',
    this.tagline      = '',
    this.registrationNo = '',
    this.logoUrl      = '',
    this.primaryColor = const Color(0xFF0D2B6B),
    this.accentColor  = const Color(0xFFF47920),
    this.phone        = '',
    this.email        = '',
    this.address      = '',
    this.website      = '',
    this.country      = 'UG',
    this.currency     = 'UGX',
    this.minLoan      = 50000,
    this.maxLoan      = 10000000,
    this.loanRate     = 18.0,
    this.penaltyRate  = 5.0,
    this.minSavings   = 10000,
    this.savingsRate  = 8.0,
    this.shareValue   = 1000,
    this.minShares    = 1,
    this.status       = 'active',
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'active';

  // ── Serialise ─────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'tenantId':       tenantId,
    'saccoName':      saccoName,
    'shortName':      shortName,
    'tagline':        tagline,
    'registrationNo': registrationNo,
    'logoUrl':        logoUrl,
    'primaryColor':   primaryColor.toARGB32(),
    'accentColor':    accentColor.toARGB32(),
    'phone':          phone,
    'email':          email,
    'address':        address,
    'website':        website,
    'country':        country,
    'currency':       currency,
    'minLoan':        minLoan,
    'maxLoan':        maxLoan,
    'loanRate':       loanRate,
    'penaltyRate':    penaltyRate,
    'minSavings':     minSavings,
    'savingsRate':    savingsRate,
    'shareValue':     shareValue,
    'minShares':      minShares,
    'status':         status,
    'updatedAt':      FieldValue.serverTimestamp(),
  };

  // ── Deserialise ───────────────────────────────────────────────────────────

  factory SaccoProfile.fromMap(Map<String, dynamic> d) {
    Color _col(dynamic raw, Color fallback) {
      if (raw is int) return Color(raw);
      return fallback;
    }

    return SaccoProfile(
      tenantId:       d['tenantId']       as String? ?? '',
      saccoName:      d['saccoName']      as String? ?? d['name'] as String? ?? 'SACCO',
      shortName:      d['shortName']      as String? ?? '',
      tagline:        d['tagline']        as String? ?? '',
      registrationNo: d['registrationNo'] as String? ?? d['regNo'] as String? ?? '',
      logoUrl:        d['logoUrl']        as String? ?? '',
      primaryColor:   _col(d['primaryColor'], const Color(0xFF0D2B6B)),
      accentColor:    _col(d['accentColor'],  const Color(0xFFF47920)),
      phone:          d['phone']          as String? ?? '',
      email:          d['email']          as String? ?? '',
      address:        d['address']        as String? ?? '',
      website:        d['website']        as String? ?? '',
      country:        d['country']        as String? ?? 'UG',
      currency:       d['currency']       as String? ?? 'UGX',
      minLoan:        (d['minLoan']       as num?)?.toInt()    ?? 50000,
      maxLoan:        (d['maxLoan']       as num?)?.toInt()    ?? 10000000,
      loanRate:       (d['loanRate']      as num?)?.toDouble() ?? 18.0,
      penaltyRate:    (d['penaltyRate']   as num?)?.toDouble() ?? 5.0,
      minSavings:     (d['minSavings']    as num?)?.toInt()    ?? 10000,
      savingsRate:    (d['savingsRate']   as num?)?.toDouble() ?? 8.0,
      shareValue:     (d['shareValue']    as num?)?.toInt()    ?? 1000,
      minShares:      (d['minShares']     as num?)?.toInt()    ?? 1,
      status:         d['status']         as String? ?? 'active',
      createdAt: _timestamp(d['createdAt']),
      updatedAt: _timestamp(d['updatedAt']),
    );
  }

  static DateTime? _timestamp(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  SaccoProfile copyWith({
    String?   saccoName,
    String?   shortName,
    String?   tagline,
    String?   registrationNo,
    String?   logoUrl,
    Color?    primaryColor,
    Color?    accentColor,
    String?   phone,
    String?   email,
    String?   address,
    String?   website,
    String?   country,
    String?   currency,
    int?      minLoan,
    int?      maxLoan,
    double?   loanRate,
    double?   penaltyRate,
    int?      minSavings,
    double?   savingsRate,
    int?      shareValue,
    int?      minShares,
    String?   status,
  }) => SaccoProfile(
    tenantId:       tenantId,
    saccoName:      saccoName      ?? this.saccoName,
    shortName:      shortName      ?? this.shortName,
    tagline:        tagline        ?? this.tagline,
    registrationNo: registrationNo ?? this.registrationNo,
    logoUrl:        logoUrl        ?? this.logoUrl,
    primaryColor:   primaryColor   ?? this.primaryColor,
    accentColor:    accentColor    ?? this.accentColor,
    phone:          phone          ?? this.phone,
    email:          email          ?? this.email,
    address:        address        ?? this.address,
    website:        website        ?? this.website,
    country:        country        ?? this.country,
    currency:       currency       ?? this.currency,
    minLoan:        minLoan        ?? this.minLoan,
    maxLoan:        maxLoan        ?? this.maxLoan,
    loanRate:       loanRate       ?? this.loanRate,
    penaltyRate:    penaltyRate    ?? this.penaltyRate,
    minSavings:     minSavings     ?? this.minSavings,
    savingsRate:    savingsRate    ?? this.savingsRate,
    shareValue:     shareValue     ?? this.shareValue,
    minShares:      minShares      ?? this.minShares,
    status:         status         ?? this.status,
    createdAt:      createdAt,
    updatedAt:      updatedAt,
  );

  // ── Default SACCO (fallback when no config loaded) ─────────────────────────

  static const SaccoProfile defaultSacco = SaccoProfile(
    tenantId:  'sacco_001',
    saccoName: 'SACCOPLUS Pro',
    tagline:   'Banking Made Simple for Every SACCO',
    country:   'UG',
    currency:  'UGX',
  );
}
