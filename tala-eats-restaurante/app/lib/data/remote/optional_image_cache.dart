import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caché opcional de referencias visuales que NO es fuente de verdad.
///
/// El catálogo y las fotografías publicadas provienen siempre de la API.
/// Errores del almacenamiento local en Android no deben bloquear Inicio,
/// Pedidos ni Menú. No usar nunca para sesión, claves, retiros o contabilidad.
class OptionalImageCache {
  OptionalImageCache({Future<SharedPreferences> Function()? load})
      : _load = load ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _load;
  final Map<String, String> _memory = <String, String>{};

  Future<String?> read(String key) async {
    try {
      final prefs = await _load();
      return prefs.getString(key) ?? _memory[key];
    } on PlatformException {
      return _memory[key];
    } on MissingPluginException {
      return _memory[key];
    } on FormatException {
      return _memory[key];
    }
  }

  Future<void> write(String key, String value) async {
    _memory[key] = value;
    try {
      final prefs = await _load();
      await prefs.setString(key, value);
    } on PlatformException {
      // No afectar el estado visible si falla una caché prescindible.
    } on MissingPluginException {
      // En modo temporal se mantiene únicamente en memoria.
    } on FormatException {
      // No almacenar datos financieros ni secretos en esta caché.
    }
  }
}
