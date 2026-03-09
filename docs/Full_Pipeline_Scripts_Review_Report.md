# Full Pipeline Scripts Review Report

Date: 2026-03-09

## Objective
Review all scripts listed in the workflow overview and identify logic, integration, and reproducibility issues that can affect final ERP outputs.

Reviewed scripts:
- `eeglab_epochs/PrepareData_6_ExtractConditions.m`
- `eeglab_epochs/extract_noaction_condition.m`
- `eeglab_epochs/extract_action_condition.m`
- `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m`
- `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m`
- `eeglab_ERP_analysis/compute_N1_P2.m`
- `eeglab_epochs/compare_N1_P2_amplitudes.m`
- `eeglab_ERP_analysis/plot_grand_average_waveforms.m`
- `eeglab_ERP_analysis/plot_scalp_topographies.m`
- `eeglab_ERP_analysis/plot_action_noaction_comparison.m`

## Executive Summary
The pipeline architecture is coherent (extract -> subtract -> compute -> visualize), but there are critical cross-script inconsistencies:
- Some downstream scripts mix processed and raw datasets in the same comparison.
- One script loads motor-subtracted files from the wrong directory.
- One plotting script expects field names that do not exist in `compute_N1_P2` outputs.
- Wrapper ordering in `PrepareData_7_ComputeERPs.m` computes NoAction metrics before the subtraction step creates matched processed pairs.

These issues can produce "incorrect-looking" Action vs NoAction results even when subtraction itself executes.

## Findings By Severity

### High Severity

1. Mixed processing states in Action vs NoAction comparison plots
- `plot_action_noaction_comparison.m` loads NoAction main from raw epoch folder:
  - `eeglab_ERP_analysis/plot_action_noaction_comparison.m:28`
- Action may be motor-subtracted from ERP output folder in same plot.
- Impact: invalid direct comparison due to inconsistent preprocessing.

2. Wrong path for motor-subtracted Action file in amplitude comparison script
- `compare_N1_P2_amplitudes.m` loads motor-subtracted Action Main from `epo_path`:
  - `eeglab_epochs/compare_N1_P2_amplitudes.m:50`
- Motor-subtracted output is saved under ERP output path (`out_path`) by subtraction routine.
- Impact: Action Main may be missing/empty in this script, silently degrading stats/plots.

3. Field-name mismatch in topography plotting script
- `plot_scalp_topographies.m` expects `results.Central.N1_lat` and `P2_lat`:
  - `eeglab_ERP_analysis/plot_scalp_topographies.m:8`
  - `eeglab_ERP_analysis/plot_scalp_topographies.m:9`
- `compute_N1_P2.m` stores `N1_peak_lat` and `P2_peak_lat`:
  - `eeglab_ERP_analysis/compute_N1_P2.m:139`
  - `eeglab_ERP_analysis/compute_N1_P2.m:142`
- Impact: runtime failure or incorrect indexing if this script is used.

### Medium Severity

4. Wrapper computes NoAction metrics before motor-subtraction stage in same run
- NoAction metrics are computed early:
  - `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m:26`
- Motor subtraction is called later:
  - `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m:52`
- Action main is then replaced with motor-subtracted file:
  - `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m:56`
- Impact: analysis order increases risk of mismatched processed states across conditions.

5. Epoch-window messaging mismatch between wrapper and extraction defaults
- Wrapper reports extended window -500 to +850 ms:
  - `eeglab_epochs/PrepareData_6_ExtractConditions.m:113`
  - `eeglab_epochs/PrepareData_6_ExtractConditions.m:121`
- Extraction defaults remain -450 to +650 ms unless cfg overrides:
  - `eeglab_epochs/extract_action_condition.m:16`
  - `eeglab_epochs/extract_noaction_condition.m:13`
- Impact: reproducibility confusion and possible assumptions mismatch for P2 coverage.

6. "Paired t-tests" claim does not match implementation
- Header claims statistical summary with paired t-tests:
  - `eeglab_epochs/compare_N1_P2_amplitudes.m:14`
- Implementation computes simple within-script differences and prints guidance for group tests:
  - `eeglab_epochs/compare_N1_P2_amplitudes.m:409`
  - `eeglab_epochs/compare_N1_P2_amplitudes.m:463`
- Impact: documentation/expectation mismatch.

### Low Severity / Design Risk

7. ERP-level subtraction strategy is explicit but may not match expected trial-level behavior
- Subtraction is done on averaged tone ERP and replicated to all tone trials:
  - `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:290`
- Impact: reduced trial variance; outputs can appear unnaturally smooth; may conflict with user expectation if they expect trial-wise subtraction.

8. Standalone plot scripts appear partially redundant with local plotting functions in wrappers
- `PrepareData_7_ComputeERPs.m` uses internal `plot_erp`/`plot_topo` helpers, while separate scripts exist.
- Impact: maintenance drift (already observed with field naming mismatch).

## Script-By-Script Review

### `PrepareData_6_ExtractConditions.m`
- Good: auto-detects Action vs NoAction by event markers and iterates all post-ICA files.
- Risk: printed messaging about extended windows is not enforced in this script.

### `extract_noaction_condition.m`
- Good: clean tone epoching, adaptation/main split, raw save strategy.
- Good: no baseline correction here aligns with downstream consistency goals.

### `extract_action_condition.m`
- Good: baseline keypress extraction plus tone-locked adaptation/main split.
- Good: comments clearly describe mapping between keypress- and tone-locked windows.

### `PrepareData_7_ComputeERPs.m`
- Good: central orchestration and fault-tolerant motor subtraction call.
- Risk: ordering can lead to mixed processing states across conditions.

### `subtract_motor_and_compute_difference.m`
- Good: comprehensive implementation of shift, align, subtract, relock, baseline, difference wave.
- Risk: ERP-level subtraction choice should be explicitly accepted as design decision.

### `compute_N1_P2.m`
- Good: consistent windowing and robust group/per-tone extraction structure.
- Good: output fields are internally coherent (`*_peak_lat`, `*_mean_amp`, etc.).

### `compare_N1_P2_amplitudes.m`
- Risk: wrong folder path for motor-subtracted Action Main.
- Risk: statistical section is descriptive differences, not inferential tests.

### `plot_grand_average_waveforms.m`
- Generally functional. Uses explicit event-epoch matching and ROI average.
- Minor note: epoch lookup loops over all events repeatedly (can be optimized, but functionally okay).

### `plot_scalp_topographies.m`
- High-risk bug due to field-name mismatch (`N1_lat/P2_lat` vs `N1_peak_lat/P2_peak_lat`).

### `plot_action_noaction_comparison.m`
- High-risk comparison inconsistency: raw NoAction mixed with motor-subtracted Action.

## Recommended Fix Plan
1. Standardize final comparison inputs to processed datasets from `eeglab_ERPs/<Sub>/` for both Action and NoAction main blocks.
2. Fix path usage in `compare_N1_P2_amplitudes.m`:
- Load Action motor-subtracted from `out_path`.
- Load NoAction baseline-corrected main (`*_main_bc.set`) from `out_path` when available.
3. Fix field names in `plot_scalp_topographies.m` to use `N1_peak_lat` and `P2_peak_lat`.
4. Reorder `PrepareData_7_ComputeERPs.m` so subtraction and dataset replacement happen before final metric computation for both conditions.
5. Align epoch-window messaging and actual defaults/config values.
6. Update comments in `compare_N1_P2_amplitudes.m` to reflect actual stats scope, or implement real subject-level inferential testing in a group script.

## Conclusion
Core extraction and subtraction logic is mostly present, but cross-script integration issues are currently the main source of unreliable outputs. Fixing path consistency, processing-state consistency, and field-name mismatches should materially improve validity of the reported Action vs NoAction N1/P2 results.
