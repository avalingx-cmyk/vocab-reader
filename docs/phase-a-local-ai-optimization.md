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

1. **KleidiAI integration** — Rebuild `llama_cpp_dart` with `-DGGML_CPU_KLEIDIAI=ON` for Arm-optimized matmul kernels (2-3x speedup on Snapdragon)
2. **GBNF grammar** — Add constrained decoding to guarantee 100% valid JSON output