# Protocol: mediapipe_genai Baseline (H2)

## Objective
Establish a performance baseline for `mediapipe_genai` using the Gemma 2B model (.task) on the target platform.

## Hypothesis
`mediapipe_genai` will offer significantly higher throughput (>20 TPS) than `llama_cpp_dart` due to GPU acceleration, but will suffer from higher initial latency (TTFT).

## Prediction
*   **TTFT:** ~2.5s
*   **TPS:** 20 - 25
*   **RAM:** 1.5GB - 1.8GB

## Method
1.  Add `mediapipe_genai` to `pubspec.yaml`.
2.  Create a benchmarking service `MediaPipeBenchmarkService`.
3.  Download/Mock Gemma 2B .task model.
4.  Run 5 iterations of a standard prompt ("Summarize the word 'Ephemeral'").
5.  Measure and record:
    *   `load_time_ms`
    *   `ttft_ms`
    *   `tokens_per_sec`
    *   `peak_ram_mb`

## Verification
The experiment is successful if the model generates a coherent summary offline using the GPU backend.
