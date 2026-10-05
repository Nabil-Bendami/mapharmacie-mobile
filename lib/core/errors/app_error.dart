import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class AppError implements Exception {
  const AppError(this.message);
  final String message;

  static AppError from(Object error) {
    if (error is AppError) return error;
    if (error is SocketException || error is TimeoutException) {
      return const AppError(
        'No internet connection. Check your network and try again.',
      );
    }
    if (error is AuthException) {
      if (error.message.toLowerCase().contains('invalid login')) {
        return const AppError('Email or password is incorrect.');
      }
      return const AppError('Authentication failed. Please try again.');
    }
    if (error is PostgrestException) {
      if (RegExp(
        r'^(Limite de |Abonnement |Entreprise :|Fonctionnalité non incluse|Lots FEFO :)',
      ).hasMatch(error.message)) {
        return AppError(error.message);
      }
      if (error.code == '42501') {
        return const AppError('You do not have permission for this action.');
      }
      if (error.code == '23505') {
        return const AppError('This barcode or product already exists.');
      }
      if (error.code == '22003' || error.code == '22023') {
        return AppError(error.message);
      }
      return const AppError(
        'The pharmacy database could not complete the request.',
      );
    }
    return const AppError('Something went wrong. Please try again.');
  }

  @override
  String toString() => message;
}
