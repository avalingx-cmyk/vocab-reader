# Phase A: Local AI Performance Optimization

**Status:** Completed  
**Date:** 2025-05-12

## Summary

This phase focused on quick wins to improve local AI inference speed on Android devices.

## Changes Made

### 1. Thread Optimization (`device_capability.dart`)

**Problem:** Using too many threads on Android's big.LITTLE architecture caused memory bus contention, slowing down inference.

**Solution:** Reduced thread count on Android:
- Flagship/High devices: 2 threads (was 6-8)
- Mid devices: 2 threads (was 2-4)
- Low devices: 1 thread (was 1-2)

**Why:** Sub-1B models are memory-bandwidth bound, not compute-bound. Using only the fastest core(s) avoids synchronization overhead with efficiency cores.

### 2. GPU Offload Disabled (`device_capability.dart`)

**Problem:** GPU offload on Android with `llama_cpp_dart` was hurting performance for sub-1B models due to transfer overhead.

**Solution:** Set `nGpuLayers = 0` for all Android devices. Desktop platforms still use GPU when available.

**Why:** Mobile GPU memory bandwidth is comparable to CPU for small models, but the data transfer overhead makes GPU slower overall.

### 3. Simplified Model Loading (`local_ai_service.dart`)

**Problem:** Complex GPU fallback logic was unnecessary and error-prone.

**Solution:** Removed GPU retry/fallback code since GPU is now disabled on Android. Cleaner loading path.

### 4. New Model Options (`local_ai_service.dart`)

**Added:**
- **SmolLM2-135M** (105 MB) — Ultra-light option for low-end devices
- **SmolLM2-360M** (280 MB) — Purpose-built for on-device inference

**Kept:**
- **Qwen 2.5 0.5B** (432-491 MB) — Best quality mid-size
- **Llama 3.2 1B** (730 MB) — Larger option for capable devices

**Removed:** Gemma 2 2B (1.6 GB) — too large for most mobile devices

### 5. Model Recommendation Updated (`device_capability.dart`)

New tier-based recommendations:
- **Flagship:** `qwen-hq` (Qwen 2.5 0.5B Q4_K_M)
- **High/Mid:** `smolm-360` (SmolLM2 360M)
- **Low:** `smolm-135` (SmolLM2 135M)

### 6. Prompt Formatter Updated (`local_ai_service.dart`)

SmolLM2 models use ChatML format (same as Qwen), already supported by `llama_cpp_dart`.

## Expected Performance Impact

| Change | Expected Speedup |
|--------|-----------------|
| Thread reduction | 1.5-2x on most devices |
| GPU disabled | 1.1-1.3x (removes overhead) |
| SmolLM2-135M vs Qwen 0.5B | 2-3x faster (smaller model) |
| SmolLM2-360M vs Qwen 0.5B | 1.5-2x faster (smaller model) |

## Files Changed

1. `lib/services/device_capability.dart` — Thread count, GPU layers, model recommendation
2. `lib/services/local_ai_service.dart` — Model list, formatter mapping, load logic

## Testing

Run `flutter analyze` — passes with only info-level warnings (print statements).

## Next Steps (Phase B)

1. **KleidiAI integration** — DONE — Added `GGML_CPU_KLEIDIAI=ON` in CMakeLists.txt
2. **GBNF grammar** — DONE — Added `word_summary_grammar.dart` with JSON grammar

---

# Phase B: KleidiAI + GBNF Grammar

**Status:** Completed  
**Date:** 2025-05-12

## Summary

This phase added KleidiAI ARM-optimized kernels for 2-3x speedup and GBNF grammar for guaranteed valid JSON output.

## Changes Made

### 1. KleidiAI CMake Flag (`llama_cpp_native/src/CMakeLists.txt`)

Added `GGML_CPU_KLEIDIAI=ON` before `add_subdirectory(llama.cpp)`:
- KleidiAI SDK auto-downloads via FetchContent during CMake configure
- ARM microkernels for dotprod, i8mm, and SME optimizations
- 2-3x speedup on Snapdragon 8 Gen 2/3/Elite
- 1.5x speedup on older devices with dotprod-only

### 2. GBNF Grammar (`word_summary_grammar.dart`)

New file defining grammar for JSON output:
```gbnf
root ::= "{" space definition-kv "," space use-cases-kv "," space similar-words-kv "}"
...
```

Enforces exactly this structure: `{"definition": "...", "useCases": [...], "similarWords": [...]}`

### 3. Grammar Integration (`local_ai_service.dart`)

- Imports `word_summary_grammar.dart`
- Wires `grammarStr` and `grammarRoot` into `SamplerParams`
- Every local LLM call now uses constrained decoding

### 4. Parser Note (`ai_service.dart`)

Added comment that GBNF guarantees valid JSON for local provider. Kept fallback logic for cloud providers.

## Expected Performance Impact

| Change | Expected Effect |
|--------|-----------------|
| KleidiAI kernels | 2-3x generation speedup on Snapdragon 8 Gen 2+ |
| GBNF grammar | 100% valid JSON, no parse errors |
| Grammar overhead | ~1-2% per generation |

## Files Changed

1. `llama_cpp_native/src/CMakeLists.txt` — Added KleidiAI flag
2. `lib/services/word_summary_grammar.dart` — NEW: GBNF grammar definitions
3. `lib/services/local_ai_service.dart` — Import and wire grammar
4. `lib/services/ai_service.dart` — Added parser note

## Build Note

First build with KleidiAI enabled will be slower (FetchContent downloads KleidiAI SDK from GitHub). Subsequent builds use cached SDK.

## Next Steps (Phase C)

**Fine-tuning a custom vocabulary model:**
- Generate 5,000-10,000 synthetic training examples
- LoRA fine-tune SmolLM2-360M for vocabulary JSON output
- Quantize and deploy as custom GGUF