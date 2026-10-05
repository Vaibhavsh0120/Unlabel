# Shared evaluation data — reserved

- fixtures/ocr: synthetic OCR text and region coordinates, including common errors.
- fixtures/scans: synthetic confirmed-label inputs and front/back pairing cases.
- fixtures/expected: reviewed expected rule results with source/rule versions.
- private: ignored local-only package photographs and manual investigation data.

No product dataset, real scan, legal verdict or source image is included yet. Future shared fixtures must record reuse rights and contain no personal information. Real user history belongs on the device, not in this repository.

Fixtures should cover missing fields, mixed nutrition bases, ambiguous additives, may-contain warnings, front/back mismatch, stale evidence and provider outages. They will support backend rules and frontend contract tests without requiring a paid service.
