import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Exchange rate fetch result
class RateFetchResult {
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final DateTime date;
  final String source;

  RateFetchResult({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.date,
    required this.source,
  });
}

/// Service for fetching exchange rates from free public APIs
/// Supports offline mode with cached rates
class RateFetchService {
  static const String _primaryApiUrl = 'https://open.er-api.com/v6/latest';
  static const String _fallbackApiUrl = 'https://api.exchangerate-api.com/v4/latest';
  
  final http.Client _client;
  
  RateFetchService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch rates for a base currency (e.g., 'CNY', 'USD')
  /// Returns rates relative to the base currency
  Future<List<RateFetchResult>> fetchRates(String baseCurrency) async {
    // Try primary API first
    try {
      final rates = await _fetchFromOpenErApi(baseCurrency);
      if (rates.isNotEmpty) return rates;
    } catch (e) {
      debugPrint('Primary API failed: $e');
    }

    // Fallback to secondary API
    try {
      final rates = await _fetchFromExchangeRateApi(baseCurrency);
      if (rates.isNotEmpty) return rates;
    } catch (e) {
      debugPrint('Fallback API failed: $e');
    }

    throw RateFetchException('无法获取汇率数据，请检查网络连接');
  }

  /// Fetch from open.er-api.com (free, no API key required)
  Future<List<RateFetchResult>> _fetchFromOpenErApi(String base) async {
    final response = await _client
        .get(Uri.parse('$_primaryApiUrl/$base'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw RateFetchException('API返回错误: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    
    if (data['result'] != null && data['result'] != 'success') {
      throw RateFetchException('API返回错误: ${data['result']}');
    }

    final rates = data['rates'] as Map<String, dynamic>?;
    if (rates == null) {
      throw RateFetchException('API返回数据格式错误');
    }

    final now = DateTime.now();
    final results = <RateFetchResult>[];

    rates.forEach((currency, rate) {
      if (rate is num && currency != base) {
        results.add(RateFetchResult(
          fromCurrency: base,
          toCurrency: currency,
          rate: rate.toDouble(),
          date: now,
          source: 'open.er-api',
        ));
      }
    });

    return results;
  }

  /// Fetch from exchangerate-api.com (free tier, no API key required)
  Future<List<RateFetchResult>> _fetchFromExchangeRateApi(String base) async {
    final response = await _client
        .get(Uri.parse('$_fallbackApiUrl/$base'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw RateFetchException('API返回错误: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final rates = data['rates'] as Map<String, dynamic>?;

    if (rates == null) {
      throw RateFetchException('API返回数据格式错误');
    }

    final now = DateTime.now();
    final results = <RateFetchResult>[];

    rates.forEach((currency, rate) {
      if (rate is num && currency != base) {
        results.add(RateFetchResult(
          fromCurrency: base,
          toCurrency: currency,
          rate: rate.toDouble(),
          date: now,
          source: 'exchangerate-api',
        ));
      }
    });

    return results;
  }

  /// Check if device is online
  Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }

  /// Fetch specific currency pair rate
  Future<RateFetchResult?> fetchSpecificRate(
    String fromCurrency,
    String toCurrency,
  ) async {
    try {
      final rates = await fetchRates(fromCurrency);
      return rates.firstWhere(
        (r) => r.toCurrency == toCurrency,
        orElse: () => throw RateFetchException('未找到汇率: $fromCurrency -> $toCurrency'),
      );
    } catch (e) {
      // Try inverse
      try {
        final inverseRates = await fetchRates(toCurrency);
        final inverseRate = inverseRates.firstWhere(
          (r) => r.toCurrency == fromCurrency,
          orElse: () => throw RateFetchException('未找到汇率'),
        );
        return RateFetchResult(
          fromCurrency: fromCurrency,
          toCurrency: toCurrency,
          rate: 1 / inverseRate.rate,
          date: inverseRate.date,
          source: inverseRate.source,
        );
      } catch (_) {
        return null;
      }
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Exception for rate fetch errors
class RateFetchException implements Exception {
  final String message;
  RateFetchException(this.message);

  @override
  String toString() => 'RateFetchException: $message';
}
