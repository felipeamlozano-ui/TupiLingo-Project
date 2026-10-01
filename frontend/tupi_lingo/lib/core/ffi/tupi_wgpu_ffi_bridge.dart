import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Native function pointer typedefs
typedef _TupiEngineCreateC = ffi.Pointer<ffi.Void> Function(ffi.Uint32 width, ffi.Uint32 height);
typedef _TupiEngineCreateDart = ffi.Pointer<ffi.Void> Function(int width, int height);

typedef _TupiEngineLoadMapC = ffi.Int32 Function(ffi.Pointer<ffi.Void> engine, ffi.Pointer<Utf8> jsonStr);
typedef _TupiEngineLoadMapDart = int Function(ffi.Pointer<ffi.Void> engine, ffi.Pointer<Utf8> jsonStr);

typedef _TupiEngineSetEpochC = ffi.Int32 Function(ffi.Pointer<ffi.Void> engine, ffi.Uint32 epochCode);
typedef _TupiEngineSetEpochDart = int Function(ffi.Pointer<ffi.Void> engine, int epochCode);

typedef _TupiEngineResizeC = ffi.Int32 Function(ffi.Pointer<ffi.Void> engine, ffi.Uint32 width, ffi.Uint32 height);
typedef _TupiEngineResizeDart = int Function(ffi.Pointer<ffi.Void> engine, int width, int height);

typedef _TupiEngineRenderFrameC = ffi.Int32 Function(ffi.Pointer<ffi.Void> engine, ffi.Float camX, ffi.Float camY, ffi.Float zoom);
typedef _TupiEngineRenderFrameDart = int Function(ffi.Pointer<ffi.Void> engine, double camX, double camY, double zoom);

typedef _TupiEngineGetTextureIdC = ffi.Int64 Function(ffi.Pointer<ffi.Void> engine);
typedef _TupiEngineGetTextureIdDart = int Function(ffi.Pointer<ffi.Void> engine);

typedef _TupiEngineDestroyC = ffi.Void Function(ffi.Pointer<ffi.Void> engine);
typedef _TupiEngineDestroyDart = void Function(ffi.Pointer<ffi.Void> engine);

/// High-Performance Rust FFI Graphics Bridge for Android Texture Widget & Desktop.
///
/// Features:
/// - Zero-copy GPU texture passing via Android SurfaceTexture / Flutter Texture ID.
/// - Offloads terrain mesh instancing, river Bézier tessellation, and frustum culling to Rust WGPU.
/// - Seamless fallback to isomorphic Dart CustomPainter on Web and unsupported hosts.
class TupiWgpuFfiBridge {
  TupiWgpuFfiBridge._();
  static final TupiWgpuFfiBridge instance = TupiWgpuFfiBridge._();

  ffi.DynamicLibrary? _dylib;
  ffi.Pointer<ffi.Void>? _engineHandle;
  bool _isNativeAvailable = false;
  int? _nativeTextureId;

  // Native function bindings
  _TupiEngineCreateDart? _createFn;
  _TupiEngineLoadMapDart? _loadMapFn;
  _TupiEngineSetEpochDart? _setEpochFn;
  _TupiEngineResizeDart? _resizeFn;
  _TupiEngineRenderFrameDart? _renderFrameFn;
  _TupiEngineGetTextureIdDart? _getTextureIdFn;
  _TupiEngineDestroyDart? _destroyFn;

  bool get isNativeAvailable => _isNativeAvailable && _engineHandle != null;
  int? get nativeTextureId => _nativeTextureId;

  /// Initializes the native dynamic library according to target host platform.
  Future<bool> initialize({int initialWidth = 1080, int initialHeight = 1920}) async {
    if (kIsWeb) {
      _isNativeAvailable = false;
      debugPrint('[TupiWgpuFfi] Web target: using isomorphic Dart 2.5D engine.');
      return false;
    }

    try {
      if (Platform.isAndroid) {
        _dylib = ffi.DynamicLibrary.open('libtupi_wgpu_engine.so');
      } else if (Platform.isWindows) {
        _dylib = ffi.DynamicLibrary.open('tupi_wgpu_engine.dll');
      } else if (Platform.isLinux) {
        _dylib = ffi.DynamicLibrary.open('libtupi_wgpu_engine.so');
      } else if (Platform.isMacOS || Platform.isIOS) {
        _dylib = ffi.DynamicLibrary.process();
      }

      if (_dylib != null) {
        _createFn = _dylib!.lookupFunction<_TupiEngineCreateC, _TupiEngineCreateDart>('tupi_engine_create');
        _loadMapFn = _dylib!.lookupFunction<_TupiEngineLoadMapC, _TupiEngineLoadMapDart>('tupi_engine_load_map_json');
        _setEpochFn = _dylib!.lookupFunction<_TupiEngineSetEpochC, _TupiEngineSetEpochDart>('tupi_engine_set_epoch');
        _resizeFn = _dylib!.lookupFunction<_TupiEngineResizeC, _TupiEngineResizeDart>('tupi_engine_resize');
        _renderFrameFn = _dylib!.lookupFunction<_TupiEngineRenderFrameC, _TupiEngineRenderFrameDart>('tupi_engine_render_frame');
        _getTextureIdFn = _dylib!.lookupFunction<_TupiEngineGetTextureIdC, _TupiEngineGetTextureIdDart>('tupi_engine_get_texture_id');
        _destroyFn = _dylib!.lookupFunction<_TupiEngineDestroyC, _TupiEngineDestroyDart>('tupi_engine_destroy');

        _engineHandle = _createFn!(initialWidth, initialHeight);
        _nativeTextureId = _getTextureIdFn!(_engineHandle!);
        _isNativeAvailable = true;
        debugPrint('[TupiWgpuFfi] Native engine initialized. Texture ID: $_nativeTextureId');
        return true;
      }
    } catch (e) {
      _isNativeAvailable = false;
      debugPrint('[TupiWgpuFfi] Native library not compiled or not found. Falling back to high-perf Dart: $e');
    }
    return false;
  }

  /// Sends the JSON map definition to the native Rust engine.
  bool loadMapDefinitionJson(String jsonDef) {
    if (!isNativeAvailable || _loadMapFn == null) return false;
    final jsonUtf8 = jsonDef.toNativeUtf8();
    try {
      final code = _loadMapFn!(_engineHandle!, jsonUtf8);
      return code == 0;
    } finally {
      malloc.free(jsonUtf8);
    }
  }

  /// Updates active temporal epoch (0: pre1500, 1: 1532, 2: 1554, etc.).
  void setEpoch(int epochCode) {
    if (!isNativeAvailable || _setEpochFn == null) return;
    _setEpochFn!(_engineHandle!, epochCode);
  }

  /// Resizes the native offscreen render target.
  void resize(int width, int height) {
    if (!isNativeAvailable || _resizeFn == null) return;
    _resizeFn!(_engineHandle!, width, height);
  }

  /// Triggers a native WGPU render pass for the current camera state.
  bool renderFrame({required double cameraX, required double cameraY, required double zoom}) {
    if (!isNativeAvailable || _renderFrameFn == null) return false;
    final res = _renderFrameFn!(_engineHandle!, cameraX, cameraY, zoom);
    return res == 0;
  }

  /// Returns a [Texture] widget if native rendering is active, or null for fallback.
  Widget? buildTextureWidget() {
    if (isNativeAvailable && _nativeTextureId != null && _nativeTextureId! >= 0) {
      return Texture(textureId: _nativeTextureId!);
    }
    return null;
  }

  /// Releases native memory allocations and GPU pipelines.
  void dispose() {
    if (_engineHandle != null && _destroyFn != null) {
      _destroyFn!(_engineHandle!);
      _engineHandle = null;
    }
    _isNativeAvailable = false;
    _nativeTextureId = null;
  }
}
