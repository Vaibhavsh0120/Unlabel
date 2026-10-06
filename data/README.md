# Shared data and recoverable catalogue

- fixtures/ocr: synthetic OCR text and region coordinates, including common errors.
- fixtures/scans: synthetic confirmed-label inputs and front/back pairing cases.
- fixtures/expected: reviewed expected rule results with source/rule versions.
- private: ignored local-only package photographs and manual investigation data.

The [catalogue/](catalogue/README.md) directory contains the compact public OFF India identity source, manifest, acquisition provenance and license texts. Setup verifies it and regenerates SQLite. It includes no nutrition tables, source product images, personal scans or legal verdicts. Future shared fixtures must record reuse rights and contain no personal information. Real user history belongs on the device.

Fixtures should cover missing fields, mixed nutrition bases, ambiguous additives, may-contain warnings, front/back mismatch, stale evidence and provider outages. They will support backend rules and frontend contract tests without requiring a paid service.
