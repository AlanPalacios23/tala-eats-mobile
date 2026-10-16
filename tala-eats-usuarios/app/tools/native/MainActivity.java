package com.talaeats.app;

import android.content.Context;
import android.content.Intent;
import android.Manifest;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationManager;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterFragmentActivity {
    private static final String CHANNEL = "com.talaeats.app/native";
    private static final String PREFS = "talaeats_secure";
    private static final String KEY_ALIAS = "talaeats_session_key_v1";
    private static final String PREF_TOKEN = "session_token";
    private static final String PREF_IV = "session_iv";
    private static final String PREF_PENDING_ORDER = "pending_order";
    private static final String PREF_PENDING_IV = "pending_order_iv";
    private String latestUri = "";
    private MethodChannel.Result pendingLocationResult;
    private static final int LOCATION_REQUEST = 9012;
    private static final int PROFILE_PHOTO_REQUEST = 9013;
    private MethodChannel.Result pendingPhotoResult;
    private int pendingPhotoUserId = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        captureIntent(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        captureIntent(intent);
    }

    private void captureIntent(Intent intent) {
        if (intent != null && intent.getDataString() != null) latestUri = intent.getDataString();
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL).setMethodCallHandler((call, result) -> {
            try {
                switch (call.method) {
                    case "writeToken":
                        writeToken(call.argument("token")); result.success(null); break;
                    case "readToken":
                        result.success(readToken()); break;
                    case "clearToken":
                        clearToken(); result.success(null); break;
                    case "writePendingOrder":
                        Integer ownerId = call.argument("userId");
                        String reference = call.argument("reference");
                        savePendingOrder(ownerId == null ? 0 : ownerId, reference);
                        result.success(null); break;
                    case "readPendingOrder":
                        result.success(readPendingOrder()); break;
                    case "clearPendingOrder":
                        clearPendingOrder(); result.success(null); break;
                    case "openUrl":
                        String url = call.argument("url");
                        if (url == null || !url.startsWith("https://")) { result.error("BAD_URL", "URL inválida", null); break; }
                        startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url))); result.success(null); break;
                    case "initialUri":
                        result.success(latestUri.isEmpty() ? null : latestUri); break;
                    case "openAppSettings":
                        Intent settingsIntent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + getPackageName())); startActivity(settingsIntent); result.success(null); break;
                    case "currentLocation":
                        provideCurrentLocation(result); break;
                    case "pickProfilePhoto":
                        Integer pickUserId = call.argument("userId"); pickProfilePhoto(pickUserId == null ? 0 : pickUserId, result); break;
                    case "profilePhotoPath":
                        Integer pathUserId = call.argument("userId"); File pathPhoto = profilePhotoFile(pathUserId == null ? 0 : pathUserId); result.success(pathPhoto.exists() ? pathPhoto.getAbsolutePath() : null); break;
                    case "clearProfilePhoto":
                        Integer clearUserId = call.argument("userId"); File profile = profilePhotoFile(clearUserId == null ? 0 : clearUserId); if (profile.exists()) profile.delete(); result.success(null); break;
                    default:
                        result.notImplemented();
                }
            } catch (Exception e) {
                result.error("NATIVE_ERROR", e.getMessage(), null);
            }
        });
    }

    private File profilePhotoFile(int userId) {
        int safeUserId = Math.max(0, userId);
        return new File(getFilesDir(), "profile_avatar_" + safeUserId + ".img");
    }

    private void pickProfilePhoto(int userId, MethodChannel.Result result) {
        if (pendingPhotoResult != null) {
            result.error("PHOTO_BUSY", "Ya hay un selector de foto abierto.", null);
            return;
        }
        pendingPhotoResult = result;
        pendingPhotoUserId = Math.max(0, userId);
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("image/*");
        startActivityForResult(intent, PROFILE_PHOTO_REQUEST);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != PROFILE_PHOTO_REQUEST || pendingPhotoResult == null) return;
        MethodChannel.Result result = pendingPhotoResult;
        int userId = pendingPhotoUserId;
        pendingPhotoResult = null;
        pendingPhotoUserId = 0;
        if (resultCode != RESULT_OK || data == null || data.getData() == null) {
            result.success(null);
            return;
        }
        Uri uri = data.getData();
        try (InputStream in = getContentResolver().openInputStream(uri);
             FileOutputStream out = new FileOutputStream(profilePhotoFile(userId), false)) {
            if (in == null) {
                result.error("PHOTO_READ", "No pudimos leer la imagen seleccionada.", null);
                return;
            }
            byte[] buffer = new byte[8192];
            int read;
            long total = 0;
            final long max = 8L * 1024L * 1024L;
            while ((read = in.read(buffer)) != -1) {
                total += read;
                if (total > max) {
                    profilePhotoFile(userId).delete();
                    result.error("PHOTO_SIZE", "La foto debe pesar menos de 8 MB.", null);
                    return;
                }
                out.write(buffer, 0, read);
            }
            out.flush();
            result.success(profilePhotoFile(userId).getAbsolutePath());
        } catch (Exception e) {
            profilePhotoFile(userId).delete();
            result.error("PHOTO_ERROR", e.getMessage(), null);
        }
    }

    private void provideCurrentLocation(MethodChannel.Result result) {
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
                checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            pendingLocationResult = result;
            requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION}, LOCATION_REQUEST);
            return;
        }
        try {
            LocationManager lm = (LocationManager) getSystemService(Context.LOCATION_SERVICE);
            Location best = null;
            for (String provider : lm.getProviders(true)) {
                Location loc = lm.getLastKnownLocation(provider);
                if (loc != null && (best == null || loc.getAccuracy() < best.getAccuracy())) best = loc;
            }
            if (best == null) { result.error("NO_LOCATION", "Activa ubicación y vuelve a intentar.", null); return; }
            java.util.HashMap<String, Double> out = new java.util.HashMap<>();
            out.put("lat", best.getLatitude()); out.put("lng", best.getLongitude()); result.success(out);
        } catch (Exception e) { result.error("LOCATION_ERROR", e.getMessage(), null); }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == LOCATION_REQUEST && pendingLocationResult != null) {
            MethodChannel.Result result = pendingLocationResult; pendingLocationResult = null;
            boolean granted = false;
            for (int grantResult : grantResults) {
                if (grantResult == PackageManager.PERMISSION_GRANTED) { granted = true; break; }
            }
            if (granted) provideCurrentLocation(result);
            else result.error("LOCATION_DENIED", "Permiso de ubicación denegado.", null);
        }
    }

    private SecretKey getOrCreateKey() throws Exception {
        KeyStore ks = KeyStore.getInstance("AndroidKeyStore"); ks.load(null);
        if (ks.containsAlias(KEY_ALIAS)) return ((KeyStore.SecretKeyEntry) ks.getEntry(KEY_ALIAS, null)).getSecretKey();
        KeyGenerator kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        kg.init(new KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
        return kg.generateKey();
    }

    private void writeToken(String token) throws Exception {
        if (token == null || token.isEmpty()) { clearToken(); return; }
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding"); cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey());
        byte[] ciphertext = cipher.doFinal(token.getBytes(StandardCharsets.UTF_8));
        SharedPreferences.Editor e = getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit();
        e.putString(PREF_TOKEN, Base64.encodeToString(ciphertext, Base64.NO_WRAP));
        e.putString(PREF_IV, Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP)); e.apply();
    }

    private String readToken() throws Exception {
        SharedPreferences p = getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String enc = p.getString(PREF_TOKEN, null), iv = p.getString(PREF_IV, null);
        if (enc == null || iv == null) return null;
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), new GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)));
        return new String(cipher.doFinal(Base64.decode(enc, Base64.NO_WRAP)), StandardCharsets.UTF_8);
    }

    private void savePendingOrder(int ownerId, String reference) throws Exception {
        if (ownerId <= 0 || reference == null || reference.length() < 1
                || reference.length() > 80 || !reference.matches("[A-Za-z0-9_-]+")) {
            throw new IllegalArgumentException("Referencia de compra inválida");
        }
        // Write-ahead log: commit() MUST finish before POST /orders begins.
        // Only account ID + opaque reference are stored; never cart/address/card.
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey());
        String record = ownerId + "|" + reference;
        String ciphertext = Base64.encodeToString(
                cipher.doFinal(record.getBytes(StandardCharsets.UTF_8)), Base64.NO_WRAP);
        String iv = Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP);
        boolean saved = getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(PREF_PENDING_ORDER, ciphertext)
                .putString(PREF_PENDING_IV, iv).commit();
        if (!saved) throw new IllegalStateException("No se pudo proteger el intento de compra");
    }

    private String readPendingOrder() throws Exception {
        SharedPreferences prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String ciphertext = prefs.getString(PREF_PENDING_ORDER, null);
        String iv = prefs.getString(PREF_PENDING_IV, null);
        if (ciphertext == null && iv == null) return null;
        if (ciphertext == null || iv == null) throw new IllegalStateException("Intento de compra incompleto");
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(),
                new GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)));
        String record = new String(
                cipher.doFinal(Base64.decode(ciphertext, Base64.NO_WRAP)),
                StandardCharsets.UTF_8);
        if (!record.matches("[0-9]+\\|[A-Za-z0-9_-]{1,80}")) {
            throw new IllegalStateException("Intento de compra ilegible");
        }
        return record;
    }

    private void clearPendingOrder() {
        boolean removed = getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .remove(PREF_PENDING_ORDER).remove(PREF_PENDING_IV).commit();
        if (!removed) throw new IllegalStateException("No se pudo limpiar el intento de compra");
    }

    private void clearToken() {
        // Logging out removes the encrypted purchase reference for that session.
        boolean cleared = getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .remove(PREF_TOKEN).remove(PREF_IV)
                .remove(PREF_PENDING_ORDER).remove(PREF_PENDING_IV).commit();
        if (!cleared) throw new IllegalStateException("No se pudo cerrar la sesión protegida");
    }
}
