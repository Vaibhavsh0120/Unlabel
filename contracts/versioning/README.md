# Future compatibility metadata

Reserve the shared API-major/contract-schema definitions and release-manifest schemas here. The Flutter starter declares `0.0.0+1` in `frontend/pubspec.yaml`. The manual release workflow injects the selected product version, build number and source commit into both mobile artifacts and records them in `build-manifest.json`.

Backend v0.1.0 exports product/OpenAPI schemas and `/v1/meta` with API major 1, contract schema 1 and product adapter 1. Knowledge remains `not_populated`; future capabilities are disabled. Frontend stays 0.0.0+1. [Release/versioning](../../docs/planning/RELEASE_VERSIONING.md) specifies which versions align and which remain independently compatible.
