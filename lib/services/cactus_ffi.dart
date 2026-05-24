import 'dart:ffi';
import 'dart:io';
import 'dart:convert';

typedef CactusModelT = Pointer<Void>;

typedef CactusInitNative = Pointer<Void> Function(
    Pointer<Int8> modelPath, Pointer<Int8> corpusDir, Bool cacheIndex);
typedef CactusInitDart = Pointer<Void> Function(
    Pointer<Int8> modelPath, Pointer<Int8> corpusDir, bool cacheIndex);

typedef CactusDestroyNative = Void Function(Pointer<Void> model);
typedef CactusDestroyDart = void Function(Pointer<Void> model);

typedef CactusStopNative = Void Function(Pointer<Void> model);
typedef CactusStopDart = void Function(Pointer<Void> model);

typedef CactusCompleteNative = Int32 Function(
    Pointer<Void> model,
    Pointer<Int8> messagesJson,
    Pointer<Int8> responseBuffer,
    IntPtr bufferSize,
    Pointer<Int8> optionsJson,
    Pointer<Int8> toolsJson,
    Pointer<Void> callback,
    Pointer<Void> userData,
    Pointer<Uint8> pcmBuffer,
    IntPtr pcmBufferSize);
typedef CactusCompleteDart = int Function(
    Pointer<Void> model,
    Pointer<Int8> messagesJson,
    Pointer<Int8> responseBuffer,
    int bufferSize,
    Pointer<Int8> optionsJson,
    Pointer<Int8> toolsJson,
    Pointer<Void> callback,
    Pointer<Void> userData,
    Pointer<Uint8> pcmBuffer,
    int pcmBufferSize);

typedef CactusGetLastErrorNative = Pointer<Int8> Function();
typedef CactusGetLastErrorDart = Pointer<Int8> Function();

DynamicLibrary _loadLib() {
  if (Platform.isAndroid) return DynamicLibrary.open('libcactus.so');
  if (Platform.isIOS) return DynamicLibrary.process();
  if (Platform.isMacOS) {
    final p = Platform.environment['CACTUS_DYLIB_PATH'];
    if (p != null) return DynamicLibrary.open(p);
    return DynamicLibrary.process();
  }
  throw UnsupportedError('Cactus not supported: ${Platform.operatingSystem}');
}

DynamicLibrary _loadCallocLib() {
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libc.so');
  }
  if (Platform.isWindows) return DynamicLibrary.process();
  if (Platform.isMacOS) return DynamicLibrary.process();
  if (Platform.isIOS) return DynamicLibrary.process();
  throw UnsupportedError('Cactus calloc: ${Platform.operatingSystem}');
}

final DynamicLibrary _lib = _loadLib();
final DynamicLibrary _callocLib = _loadCallocLib();

Pointer<T> _malloc<T extends NativeType>(int size) {
  final allocFn = _callocLib
      .lookup<NativeFunction<Pointer<Void> Function(IntPtr, IntPtr)>>('calloc')
      .asFunction<Pointer<Void> Function(int, int)>();
  return allocFn(size, 1).cast<T>();
}

void _free(Pointer ptr) {
  final freeFn = _callocLib
      .lookup<NativeFunction<Void Function(Pointer<Void>)>>('free')
      .asFunction<void Function(Pointer<Void>)>();
  freeFn(ptr.cast<Void>());
}

Pointer<Int8> stringToPtr(String s) {
  final units = utf8.encode(s);
  final ptr = _malloc<Int8>(units.length + 1);
  for (var i = 0; i < units.length; i++) ptr[i] = units[i];
  ptr[units.length] = 0;
  return ptr;
}

String ptrToString(Pointer<Int8> ptr) {
  if (ptr == nullptr) return '';
  final codes = <int>[];
  var i = 0;
  while (true) {
    final byte = ptr[i];
    if (byte == 0) break;
    codes.add(byte);
    i++;
  }
  return utf8.decode(codes);
}

void freePtr(Pointer ptr) => _free(ptr);

final _cactusInit =
    _lib.lookupFunction<CactusInitNative, CactusInitDart>('cactus_init');
final _cactusDestroy =
    _lib.lookupFunction<CactusDestroyNative, CactusDestroyDart>('cactus_destroy');
final _cactusStop =
    _lib.lookupFunction<CactusStopNative, CactusStopDart>('cactus_stop');
final _cactusComplete =
    _lib.lookupFunction<CactusCompleteNative, CactusCompleteDart>('cactus_complete');
final _cactusGetLastError =
    _lib.lookupFunction<CactusGetLastErrorNative, CactusGetLastErrorDart>(
        'cactus_get_last_error');

Pointer<Void> init(String modelPath, String? corpusDir, bool cacheIndex) {
  final mp = stringToPtr(modelPath);
  final cd = corpusDir != null ? stringToPtr(corpusDir) : nullptr;
  final handle = _cactusInit(mp, cd, cacheIndex);
  freePtr(mp);
  if (cd != nullptr) freePtr(cd);
  if (handle == nullptr) {
    throw Exception('cactus_init failed: ${lastError()}');
  }
  return handle;
}

void destroy(Pointer<Void> model) => _cactusDestroy(model);

void stop(Pointer<Void> model) => _cactusStop(model);

String complete(
  Pointer<Void> model,
  String messagesJson,
  String? optionsJson,
) {
  const responseBufferSize = 65536;
  final responseBuf = _malloc<Int8>(responseBufferSize);
  final msg = stringToPtr(messagesJson);
  final opt = optionsJson != null ? stringToPtr(optionsJson) : nullptr;

  try {
    final result = _cactusComplete(
      model,
      msg,
      responseBuf,
      responseBufferSize,
      opt,
      nullptr,
      nullptr,
      nullptr,
      nullptr,
      0,
    );
    if (result < 0) {
      throw Exception('cactus_complete failed: ${lastError()}');
    }
    return ptrToString(responseBuf);
  } finally {
    freePtr(responseBuf);
    freePtr(msg);
    if (opt != nullptr) freePtr(opt);
  }
}

String lastError() {
  final ptr = _cactusGetLastError();
  if (ptr == nullptr) return '';
  return ptrToString(ptr);
}
