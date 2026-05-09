# Project Requirements

## Performance & Optimization
- **REQ-001**: The application MUST be optimized for production release using code minification (R8/ProGuard).
- **REQ-002**: The application MUST support Android App Bundle (AAB) format for Play Store distribution.
- **REQ-003**: The application MUST be buildable as split-per-ABI APKs to reduce individual file sizes for direct distribution.
- **REQ-004**: Total application binary size SHOULD be minimized, targeting major bloat points (>1MB) identified through size analysis.
