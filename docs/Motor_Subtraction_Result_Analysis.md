# Motor Subtraction Result Analysis

## Scope
This review checked the motor subtraction process against the intended 6-step workflow and traced where downstream outputs can become inconsistent.

Files reviewed:
- `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m`
- `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m`
- `eeglab_ERP_analysis/plot_action_noaction_comparison.m`
- `eeglab_ERP_analysis/compute_N1_P2.m`
- `eeglab_epochs/extract_action_condition.m`
- `eeglab_epochs/extract_noaction_condition.m`
- `eeglab_epochs/compare_N1_P2_amplitudes.m`

## Step-by-Step Check (Requested Process)

### Step 1: Build motor template from keypress-locked baseline
Status: Implemented.

Evidence:
- Baseline keypress epochs are loaded and baseline-corrected before averaging.
- `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:174`

Assessment:
- Logic is correct in principle.
- Motor baseline window fallback is defensive and acceptable.

### Step 2: Shift Action Main from tone-lock to keypress-lock (-250 ms)
Status: Implemented.

Evidence:
- `EEG_kp.times = EEG_main_ac.times - kp_offset_ms`.
- `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:200`

Assessment:
- Time-axis shift is correct for relabeling reference.
- Script also checks window alignment against baseline template.

### Step 3: Subtract motor template with sample alignment
Status: Implemented, but with a design choice that can distort expected output.

Evidence:
- Per-tone ERP average is computed, template subtracted, then copied back into every trial of that tone.
- `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:290`

Assessment:
- This is ERP-level subtraction, not trial-level subtraction.
- Replacing all epochs with one cleaned ERP removes trial variability and can make outputs look unnaturally smooth/flat.
- If expected output is trial-preserving, this is a likely mismatch with expectations.

### Step 4: Shift cleaned data back to tone-lock (+250 ms)
Status: Implemented.

Evidence:
- `EEG_tone.times = EEG_subtracted.times + kp_offset_ms`.
- `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:309`

Assessment:
- Time axis is returned correctly.
- Potential caveat: only `times/xmin/xmax` are shifted; event latency metadata is not explicitly rebuilt. Current helper functions partially compensate, but this is fragile.

### Step 5: Apply identical baseline [-200, 0] ms re tone to Action and No-Action
Status: Implemented inside subtraction script.

Evidence:
- Action baseline correction: `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:334`
- No-Action baseline correction: `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:352`
- Baseline-corrected No-Action main is saved to ERP output path.
- `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:355`
- `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:356`

Assessment:
- Inside this script, both conditions are baseline-corrected consistently.
- However, downstream scripts do not consistently use these corrected files (see Findings 1 and 2).

### Step 6: Compute/compare N1-P2 and difference wave
Status: Partially consistent.

Evidence:
- Difference wave in subtraction script uses corrected action/no-action sets.
- Downstream comparison plotting loads raw no-action main from epoch folder.
- `eeglab_ERP_analysis/plot_action_noaction_comparison.m:28`

Assessment:
- The subtraction module itself is mostly coherent.
- The full pipeline comparison stage mixes processed and raw data, which can make the motor subtraction result appear wrong.

## Key Findings (Root Causes)

1. Dataset mismatch in downstream comparisons (highest impact)
- `plot_action_noaction_comparison.m` compares motor-subtracted Action (from ERP folder) against raw No-Action main (from epoch folder).
- `eeglab_ERP_analysis/plot_action_noaction_comparison.m:28`
- This violates the intended "identical baseline and processing" requirement and can produce misleading Action vs No-Action differences.

2. Inconsistent metric computation order in wrapper
- `PrepareData_7_ComputeERPs.m` computes No-Action metrics before subtraction stage, using raw `na_main`.
- `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m:26`
- Action main may then be replaced with motor-subtracted data later.
- `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m:56`
- Result: summary outputs can mix differently processed inputs.

3. Path bug in amplitude comparison script
- `compare_N1_P2_amplitudes.m` attempts to load motor-subtracted action main from `epo_path`.
- `eeglab_epochs/compare_N1_P2_amplitudes.m:50`
- But motor-subtracted file is saved to ERP output path (`out_path`), not epoch path.
- This can silently skip/empty Action Main in that script.

4. ERP-level subtraction method can hide expected behavior
- Current code subtracts at averaged ERP level and replicates to all trials.
- `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m:290`
- This is not wrong mathematically for an ERP-focused outcome, but it is a strong modeling choice and often differs from expected trial-level subtraction in event-related analyses.

## What Is Likely Going Wrong in Practice
The main subtraction routine is not the only issue. The strongest failure mode is pipeline inconsistency after subtraction:
- Action data is sometimes motor-subtracted and baseline-corrected.
- No-Action data is sometimes still raw (or processed differently) in plots/stats.
- Some scripts point to the wrong folder for motor-subtracted files.

This creates an "incorrect output" impression even when core subtraction steps run successfully.

## Recommended Fix Order
1. Standardize all downstream scripts to load post-processed datasets from `eeglab_ERPs/<Sub>/` for final Action vs No-Action comparison.
2. In `PrepareData_7_ComputeERPs.m`, compute both conditions after subtraction/prep so both use matched processing.
3. Fix `compare_N1_P2_amplitudes.m` file paths (use `out_path` for motor-subtracted and baseline-corrected main datasets).
4. Decide explicitly between ERP-level and trial-level subtraction, then document that decision in code and report output accordingly.

## Conclusion
The motor subtraction steps (time shift, alignment checks, subtraction, re-locking, baseline) are largely implemented. The dominant issue is inconsistent dataset usage in later analysis/plot scripts, plus one path bug. These are sufficient to produce incorrect-looking final results even if the subtraction script itself executes without error.
