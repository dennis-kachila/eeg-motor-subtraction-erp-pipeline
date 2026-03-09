# Final Motor Subtraction Audit Report

Date: 2026-03-09

## Purpose
This final report consolidates all prior reviews into one document and maps findings directly to the required checklist:
- Subtraction-logic review
- Time-axis verification
- Sample alignment verification
- ERP-level vs trial-level assessment
- Baseline consistency verification
- Bug-fix and one-subject testing status

Reviewed files:
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

## Requirement-by-Requirement Results

### 1. Review subtraction logic in `subtract_motor_and_compute_difference.m` and identify where it goes wrong (or any other file)
Status: Completed.

Findings:
- Core subtraction pipeline is present and mostly coherent in `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m`.
- Major practical failure is cross-script inconsistency after subtraction, not only inside this file.
- High-impact issues outside core subtraction:
  - Raw vs processed dataset mixing in comparison plot flow:
    - `eeglab_ERP_analysis/plot_action_noaction_comparison.m:28`
  - NoAction metrics computed before matched post-subtraction state:
    - `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m:26`
    - `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m:52`
  - Motor-subtracted Action path bug in amplitude script:
    - `eeglab_epochs/compare_N1_P2_amplitudes.m:50`

### 2. Verify time-axis shift before and after subtraction
Status: Completed and verified as logically correct.

Evidence:
- Tone -> keypress shift:
  - `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:200`
- Keypress -> tone shift:
  - `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:309`

Assessment:
- The implemented `-250 ms` then `+250 ms` re-referencing is correct in principle.
- Caveat: event timing metadata is not fully rebuilt after shifts; current downstream helpers partly compensate.

### 3. Check sample-for-sample alignment of motor template vs Action Main prior to subtraction
Status: Completed.

Evidence:
- Script checks shifted windows and aligns template by start index/pad/trim logic before subtraction.
- Alignment and shape checks are explicitly enforced in `subtract_motor_and_compute_difference.m`.

Assessment:
- Sample alignment handling exists and is robust enough for fixed-window matching.
- Potential sensitivity remains if acquisition timing jitter requires per-trial keypress anchoring rather than fixed global offset only.

### 4. Assess ERP-level vs trial-level subtraction appropriateness
Status: Completed.

Decision:
- Trial-level subtraction is more appropriate as the primary approach for this design.

Reason:
- ERP-level approach in current code subtracts on averaged ERP and replicates cleaned waveform into all trials:
  - `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:290`
- This removes realistic trial variability and can distort downstream variance-sensitive analyses.
- For a fixed template, ERP-level and trial-level means are mathematically equivalent, but trial-level preserves physiologically meaningful trial structure.

Recommendation:
- Use trial-level subtraction as default.
- Keep ERP-level subtraction only as optional sensitivity/visualization analysis (without overwriting trial data).

### 5. Ensure final baseline correction `[-200, 0] ms re tone` is identical for Action and No-Action
Status: Core implementation verified, downstream usage inconsistent.

Evidence in subtraction module:
- Action baseline application:
  - `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:334`
- NoAction baseline application:
  - `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:352`
- Baseline-corrected NoAction main save:
  - `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:355`

Assessment:
- Baseline correction is applied correctly and symmetrically inside subtraction script.
- Some downstream scripts still read raw NoAction main, breaking intended parity.

### 6. Fix bugs in all files and test on at least one subject
Status: Not executed in this combined-document step.

Current state:
- This final report consolidates analysis findings and fix recommendations.
- Code fixes and subject-level runtime validation were not performed in this specific request.

Blocking detail:
- No one-subject runtime execution with confirmed local sample data was performed here, so test evidence cannot be claimed.

## Consolidated Critical Issues

1. Comparison scripts mix processed and raw datasets
- High risk of invalid Action vs NoAction conclusions.

2. Wrong path usage for motor-subtracted file in `compare_N1_P2_amplitudes.m`
- Can lead to missing Action Main input.

3. `plot_scalp_topographies.m` field mismatch with `compute_N1_P2.m`
- Uses `N1_lat/P2_lat` but producer outputs `N1_peak_lat/P2_peak_lat`.

4. Wrapper order can produce unmatched processing stages in outputs
- NoAction computed before subtraction stage harmonizes Action processing.

5. Epoch-window messaging mismatch
- Wrapper says extended windows; extraction defaults remain narrower unless cfg override is active.

## Final Technical Position
The subtraction routine itself is largely functional (shift, align, subtract, relock, baseline), but final output quality is degraded primarily by integration errors across scripts and by ERP-level replication behavior. The most defensible scientific implementation for this paradigm is trial-level subtraction with matched post-processing inputs for both conditions.

## Implementation and Test Plan (Next Step)
1. Refactor subtraction to trial-level mode in `subtract_motor_and_compute_difference.m`.
2. Standardize all final comparison loads to processed files in `eeglab_ERPs/<Sub>/`.
3. Fix path in `compare_N1_P2_amplitudes.m`.
4. Fix field names in `plot_scalp_topographies.m`.
5. Reorder `PrepareData_7_ComputeERPs.m` to ensure matched processing state prior to metric computation.
6. Run pipeline on at least one subject and save:
- motor template figure
- motor-subtracted Action ERP
- NoAction ERP (matched baseline-corrected)
- difference wave
- brief run log with file paths and epoch counts

## Deliverable Summary
This document is the integrated final audit report requested from all prior analyses plus your explicit checklist requirements.
