# Runtime Reference: 2026-06-12 Landowner And Map Evidence

These screenshots were copied from a local FS25 runtime test and preserved as
design evidence for Rural Ledger's map-first landowner rule.

The prompt-provided 8.3 alias paths for several screenshots were not available
on disk, so the matching canonical Steam screenshot files were copied from:

`C:\Program Files (x86)\Steam\userdata\32356266\760\remote\2300320\screenshots`

## Files

- `contracts-field-landowner-reference.jpg`: contract screen with NPC
  landowner presentation, job type, field ID, reward, map position, equipment,
  and contract detail.
- `map-crop-types-field-numbers.jpg`: crop-type map layer showing numbered
  fields, current crop coverage, and existing plot layout.
- `map-growth-stage-field-state.jpg`: growth map layer showing field states
  such as stubble tillage, cultivated, growing, ready to harvest, harvested, and
  withered.
- `map-soil-composition-field-state.jpg`: soil-composition layer showing weeds,
  ploughing, rolling, mulching, stones, and watered states.
- `precision-farming-ph-reference.jpg`: official Precision Farming pH layer
  showing field pH bands and environmental-score context.
- `precision-farming-nitrogen-reference.jpg`: official Precision Farming
  nitrogen layer showing nitrogen bands and environmental-score context.

## Design Use

Use these screenshots to keep future implementation aligned with the player's
actual map:

- Rural Ledger farms should derive from existing landowners/properties where
  possible.
- Field numbers, crop types, growth stages, soil state, and Precision Farming
  values are candidate inputs to profile and stress calculations.
- Contracts should be correlated back to field or farmland IDs before Rural
  Ledger adds narrative context.
- Synthetic farm records are only a temporary fallback while runtime APIs are
  being verified.
