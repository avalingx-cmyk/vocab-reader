# Protocol: llama_cpp_dart Baseline (H1)

## Objective
Establish a performance baseline for `llama_cpp_dart` using the Llama 3.2 1B model (Q4_K_M) on the target platform.

## Hypothesis
`llama_cpp_dart` will provide interactive speeds (>10 TPS) with a RAM footprint under 1GB, making it suitable for mid-range devices.

## Prediction
*   **TTFT:** < 1.5s
*   **TPS:** 10 - 15
*   **RAM:** 700MB - 900MB

## Method
1.  Add `llama_cpp_dart` to `pubspec.yaml`.
2.  Create a benchmarking service `LlamaBenchmarkService`.
3.  Download/Mock Llama 3.2 1B Q4_K_M GGUF.
4.  Run 5 iterations of a standard prompt ("Summarize the word 'Ephemeral'").
5.  Measure and record:
    *   `load_time_ms`
    *   `ttft_ms`
    *   `tokens_per_sec`
    *   `peak_ram_mb`

## Verification
The experiment is successful if the model generates a coherent summary offline.
