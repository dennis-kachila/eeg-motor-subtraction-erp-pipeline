# Implemented Changes Summary

Date: 2026-03-09
Branch: `feature/motor-subtraction-fixes`

## Purpose
This document records the code changes implemented to address the motor-subtraction and cross-script consistency issues identified in the project instructions and audit reports.

## High-Level Outcome
The pipeline was updated to:
- Use trial-level motor-template subtraction in the core subtraction script.
- Prefer matched processed datasets for Action vs NoAction comparisons.
- Fix incorrect path usage for motor-subtracted files.
- Reorder ERP orchestration so condition metrics are computed after preprocessing is harmonized.
- Fix a field-name mismatch in the standalone topography plotting helper.
- Align extraction wrapper messaging with actual configured/default epoch windows.

## Files Changed

### 1) `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m`
Implemented:
- Replaced ERP-level subtraction (average-per-tone then replicate to all epochs) with trial-level subtraction.
- New behavior subtracts the aligned motor template from each trial directly:
  - `EEG_subtracted.data = EEG_kp_bc.data - template_3d`
- `collapsed_erp_clean` is now computed from trial-level cleaned data (`mean(...,3)`) for grand-average difference plotting.

Why:
- Preserves realistic trial variability.
- Matches the recommended primary analysis strategy from the review docs.

### 2) `eeglab_ERP_analysis/plot_action_noaction_comparison.m`
Implemented:
- NoAction Main loading now prefers processed baseline-corrected file from ERP outputs:
  - `<out_path>/<Sub>_ses-01_task-no-action_eeg_main_bc.set`
- Falls back to raw epoch file only if processed file is missing.

Why:
- Prevents mixed processing states (processed Action vs raw NoAction) in comparison figures.

### 3) `eeglab_epochs/compare_N1_P2_amplitudes.m`
Implemented:
- Action Main motor-subtracted file now loads from `out_path` (ERP folder), not `epo_path`.
- NoAction Main now prefers processed baseline-corrected file from `out_path`, with raw fallback.
- Header comment updated from "paired t-tests" to "descriptive within-subject summary statistics" to match current implementation.

Why:
- Fixes a path bug causing missing/incorrect Action Main input.
- Improves processing parity and documentation accuracy.

### 4) `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m`
Implemented:
- Reordered flow so motor subtraction runs before final condition metric computation.
- After subtraction, wrapper loads processed NoAction Main (`*_main_bc.set`) when available.
- NoAction result computation/plotting block now runs after harmonization step.

Why:
- Reduces risk that NoAction metrics are computed on raw data while Action uses motor-subtracted data.

### 5) `eeglab_ERP_analysis/plot_scalp_topographies.m`
Implemented:
- Fixed field names to match `compute_N1_P2.m` outputs:
  - `N1_peak_lat` and `P2_peak_lat` (instead of `N1_lat` and `P2_lat`).

Why:
- Removes runtime/logic mismatch between producer and consumer structures.

### 6) `eeglab_epochs/PrepareData_6_ExtractConditions.m`
Implemented:
- Updated condition-detection log text.
- Removed hardcoded "extended epoch window" print statement.
- Now prints configured window values when present, otherwise indicates extraction defaults.

Why:
- Aligns runtime messaging with actual configuration behavior.

## Validation Performed
- Ran static error checks on edited files.
- No blocking syntax/compile errors were introduced.
- Remaining diagnostics are non-blocking lint-style notices (for example: potentially unused arguments in function signatures).

## Not Yet Performed
- Full one-subject runtime execution inside MATLAB/EEGLAB was not run in this session.
- Therefore, this document does not claim verified end-to-end figure/data outputs from execution.

## Recommended Verification Run
1. Run `eeglab_ERP_analysis/run_compute_ERPs.m` for `sub-01`.
2. Confirm these outputs are present in `eeglab_ERPs/sub-01/`:
   - motor template figure
   - motor-subtracted Action Main figure
   - NoAction Main (baseline-corrected) figure
   - difference wave figures
   - processed `.set` files (`*_motor_subtracted.set`, `*_main_bc.set`)
3. Inspect N1/P2 windows visually for plausibility and parity of preprocessing between conditions.

## Notes
- All changes were implemented on branch `feature/motor-subtraction-fixes`.
- If desired, this summary can be linked from `README.md` under a "Recent Fixes" section.



