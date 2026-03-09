# End-to-End Implementation and Validation Report

Date: 2026-03-09
Branch: `feature/motor-subtraction-fixes`
Subject tested: `sub-01`

## 1. Scope and Objective
This report documents:
- what was changed in code,
- why each change was made,
- what runtime issues were encountered,
- how each issue was resolved,
- and the final validation results from repeated runs.

It consolidates the detailed reasoning and outcomes discussed during implementation and testing.

## 2. Initial Problem Definition
Per `Project_Instructions.md`, the pipeline ran without crashing but produced incorrect-looking motor-subtraction outcomes. The key scientific requirement was valid comparison of Action Main vs No-Action Main after proper motor contamination removal.

Intended method:
1. Build keypress-locked motor template from Action baseline.
2. Shift Action main tone-locked epochs to keypress reference (-250 ms).
3. Subtract aligned motor template.
4. Shift back to tone reference (+250 ms).
5. Apply identical baseline correction `[-200, 0] ms` re tone to both conditions.
6. Compute and compare N1/P2.

## 3. Root Causes Identified
The major problems were integration-level inconsistencies rather than a single syntax/runtime bug.

### 3.1 Mixed processing states in comparisons
Some scripts compared motor-subtracted Action to raw No-Action, violating matched preprocessing assumptions.

### 3.2 Wrong file path for motor-subtracted Action main
One script loaded motor-subtracted Action from the epoch folder instead of ERP output folder.

### 3.3 ERP wrapper order mismatch
No-Action metrics were computed before subtraction harmonization was complete.

### 3.4 ERP-level subtraction behavior
Original subtraction replaced all trials in a tone class with one cleaned ERP (average-level subtraction replicated per trial), reducing trial variability.

### 3.5 Field mismatch in topography helper
`plot_scalp_topographies.m` expected field names not produced by `compute_N1_P2.m`.

### 3.6 Epoch window messaging mismatch
Top-level extraction wrapper printed hardcoded extended windows that could differ from actual config/default behavior.

## 4. Code Changes Implemented

### 4.1 `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m`
- Switched from ERP-level replicated subtraction to trial-level subtraction:
  - `EEG_subtracted.data = EEG_kp_bc.data - template_3d`
- Kept `collapsed_erp_clean` as average from trial-level cleaned data for grand difference plotting.
- Later hardening pass: explicit time-axis harmonization of NoAction to Action grid in Step 7 to avoid fragile branch behavior and warning churn.

Why:
- Preserves realistic trial structure.
- Maintains deterministic Action/NoAction subtraction behavior when tiny sample-grid differences occur.

### 4.2 `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m`
- Reordered flow so subtraction runs before final metrics are computed.
- Added preference for processed NoAction main (`*_main_bc.set`) from ERP output after subtraction stage.

Why:
- Prevents cross-condition metric mismatch from mixed preprocessing stage.

### 4.3 `eeglab_ERP_analysis/plot_action_noaction_comparison.m`
- NoAction main now prefers processed baseline-corrected file in ERP output.
- Raw epoch file used only as fallback.

Why:
- Ensures final comparison visuals use matched preprocessing where available.

### 4.4 `eeglab_epochs/compare_N1_P2_amplitudes.m`
- Action motor-subtracted main load path fixed to `out_path`.
- NoAction main prefers baseline-corrected file from `out_path`, with fallback.
- Header text updated from "paired t-tests" to descriptive within-subject summary wording.

Why:
- Correct file resolution and documentation accuracy.

### 4.5 `eeglab_ERP_analysis/plot_scalp_topographies.m`
- Field names updated to `N1_peak_lat` and `P2_peak_lat`.

Why:
- Matches producing function output schema and avoids runtime mismatch.

### 4.6 `eeglab_epochs/PrepareData_6_ExtractConditions.m`
- Replaced hardcoded "extended window" status text with cfg-aware/default-aware messaging.

Why:
- Improves reproducibility clarity.

### 4.7 Repository/runtime support additions for local execution
- Added `.gitignore` with MATLAB/temp/output rules.
- Added sample-data run guide: `docs/How_To_Run_With_Sample_Datasets.md`.
- Added minimal local helpers required by this repo snapshot:
  - `GetFilePathsAndInitializeToolboxes.m`
  - `SaveMyData.m`

Why:
- The snapshot lacked project helper files needed for execution in this environment.

## 5. Data and Runtime Issues Encountered During Validation

### 5.1 Missing EEGLAB in environment
Initial checks returned:
- `eeglab` not found
- `pop_loadset` not found
- `topoplot` not found

Resolution:
- Installed EEGLAB from official repo into `external/eeglab`.
- Added EEGLAB to MATLAB path for run.

### 5.2 Missing `.fdt` companions in first sample package
Initial sample `.set` files referenced external `.fdt` files not present.

Explanation provided:
- `.set` = metadata
- `.fdt` = signal matrix payload
- many EEGLAB datasets require both

Resolution:
- Requested full sample package from client.
- After replacement, verified full `.set` + `.fdt` availability and successful EEGLAB loading.

## 6. Validation Execution History

### Run phase A (first successful full run)
- Pipeline completed end-to-end for `sub-01`.
- Core outputs generated.
- Warning observed: Action shifted window and baseline template window mismatch.

### Corrective phase B (Option 1 requested)
- Re-epoched Action adaptation/main/baseline from continuous data with matched physical windows.
- Reran pipeline.
- Result: Action-vs-template alignment warning removed; "perfect match" achieved.
- Remaining small warning: Action vs NoAction time vectors differed by a few ms/samples, handled via interpolation.

### Corrective phase C (NoAction normalization requested)
- Re-epoched NoAction adaptation/main from continuous data using Action tone window.
- Reran pipeline.
- Residual tiny sample mismatch persisted due rounding/discontinuity handling.

### Hardening phase D (code-level stabilization)
- Updated Step 7 difference-wave code to always harmonize NoAction to Action grid explicitly.
- Reran pipeline.
- Result: previous mismatch warning replaced by controlled info message; deterministic behavior retained.

## 7. Final Runtime Results (Confirmed)
Generated under `eeglab_ERPs/sub-01/`:
- `sub-01_ses-02_task-action_eeg_main_action_motor_subtracted.set/.fdt`
- `sub-01_ses-01_task-no-action_eeg_main_bc.set/.fdt`
- `sub-01_difference_wave_motor_subtracted.mat`
- `sub-01_ERP_results_action.mat`
- `sub-01_ERP_results_noaction.mat`
- `sub-01_ERP_results.csv`
- `sub-01_ERP_results.xlsx`

Figures generated (subset):
- `sub-01_motor_template.png`
- `sub-01_action_main_motor_subtracted.png`
- `sub-01_diff_wave_motor_subtracted_per_tone.png`
- `sub-01_diff_wave_motor_subtracted_all.png`
- `sub-01_Action_vs_NoAction_Collapsed.png`
- `sub-01_Action_vs_NoAction_PerTone.png`
- plus Action/NoAction adaptation/main grand averages and topographies.

Trial counts seen in successful runs:
- Action main: 536
- NoAction main: 518
- Action baseline: 60 (after re-epoch step)

## 8. Warning Interpretation and Current Risk Status

### Resolved warnings
- Action shifted window vs baseline template mismatch: resolved by re-epoching Action files (Option 1).

### Controlled/acceptable informational behavior
- Tiny Action/NoAction sample-grid difference is now handled explicitly in code with harmonization to Action grid.
- This no longer appears as an uncontrolled warning branch in subtraction logic.

Observed detail from validated runs:
- Action axis: `[-449, 641] ms` (280 samples)
- NoAction axis: `[-449, 637] ms` (279 samples)

Explanation:
- At 256 Hz, one sample is approximately `3.906 ms` (reported as `~4 ms`).
- This can arise from EEGLAB epoch boundary rounding/discontinuity handling after epoching and baseline operations.

Mitigation implemented:
- In `subtract_motor_and_compute_difference.m` (Step 7), NoAction trial data is explicitly interpolated to the Action time grid before per-tone and collapsed difference-wave computation.
- This makes the subtraction/comparison deterministic and removes fragile mismatch branching.

### Non-critical EEGLAB environment warnings
- EEGLAB path/plugin notices remain informational and did not block execution.

## 9. Scientific/Analysis Position After Fixes
- Motor subtraction now operates at trial level.
- Final Action vs NoAction comparisons now preferentially consume matched processed datasets.
- Baseline parity (`[-200, 0]` ms) is applied in subtraction flow for both conditions.
- End-to-end outputs for one subject are reproducibly generated in this environment.

## 10. Files Most Relevant to the Delivered Fix
- `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m`
- `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m`
- `eeglab_ERP_analysis/plot_action_noaction_comparison.m`
- `eeglab_epochs/compare_N1_P2_amplitudes.m`
- `eeglab_ERP_analysis/plot_scalp_topographies.m`
- `eeglab_epochs/PrepareData_6_ExtractConditions.m`
- `docs/Implemented_Changes_Summary_2026-03-09.md`
- `docs/How_To_Run_With_Sample_Datasets.md`

## 11. Recommended Finalization Steps
1. Review generated figures in `eeglab_ERPs/sub-01/figures` for expected morphology.
2. Commit the finalized code and docs.
3. Run the same flow for additional subjects to confirm consistency.
4. If needed for methods reporting, explicitly note trial-level subtraction and time-grid harmonization policy.

## 12. How To Understand The Results (Plain Language)

This section explains what the outputs mean without requiring ERP expertise.

### 12.0 What are N1 and P2 peaks?
- `N1`:
  - An early negative-going auditory ERP component.
  - In this project it is searched in the `80-150 ms` window after tone onset.
  - `N1_Peak_Amp_uV` = the most negative value found in that window.
  - `N1_Peak_Lat_ms` = the time (ms) where that most negative value occurs.

- `P2`:
  - A later positive-going auditory ERP component.
  - In this project it is searched in the `150-275 ms` window after tone onset.
  - `P2_Peak_Amp_uV` = the most positive value found in that window.
  - `P2_Peak_Lat_ms` = the time (ms) where that most positive value occurs.

Why "peak" matters:
- Peak amplitude tells you how strong that component is.
- Peak latency tells you when that component happens.
- Together they summarize shape and timing differences between conditions.

### 12.1 What the CSV file is
File:
- `eeglab_ERPs/sub-01/sub-01_ERP_results.csv`

Each row is one condition and one tone (`Low`, `Medium`, `High`).

What these tone labels mean:
- `Low` corresponds to event type `Tone_Low`
- `Medium` corresponds to event type `Tone_Med`
- `High` corresponds to event type `Tone_High`
- They represent the three auditory tone categories in the task (low-, mid-, high-frequency tones).
- This codebase does not store the exact numeric Hz values for these categories; those come from the acquisition paradigm settings.

Key columns:
- `Condition`: `Action_Main` or `NoAction_Main`
- `N1_Peak_Amp_uV`: strongest negative deflection in 80-150 ms window
- `N1_Peak_Lat_ms`: timing of that N1 peak
- `P2_Peak_Amp_uV`: strongest positive deflection in 150-275 ms window
- `P2_Peak_Lat_ms`: timing of that P2 peak
- `N_Epochs`: number of trials used for that tone

Important sign note:
- Plotting is set to "negative-up" for visualization.
- CSV values are still standard amplitudes in microvolts.
- More negative N1 value means a larger N1 negativity.

### 12.2 What this subject (`sub-01`) shows in the CSV

From `Action_Main` vs `NoAction_Main` (Action minus NoAction):
- `Low`: `DeltaN1 = +3.065 uV`, `DeltaP2 = +5.861 uV`
- `Medium`: `DeltaN1 = +4.056 uV`, `DeltaP2 = +6.450 uV`
- `High`: `DeltaN1 = +4.414 uV`, `DeltaP2 = +5.266 uV`

Interpretation of these deltas:
- Positive `DeltaN1` here means Action N1 is less negative than NoAction N1 (attenuated N1 magnitude).
- Positive `DeltaP2` means Action P2 is more positive than NoAction P2 in this single subject.

Scope caution:
- This is one-subject output, not group-level statistical evidence.
- Use as pipeline/processing validation and preliminary signal check.

## 13. How To Read The Plot Files

### 13.1 Core motor-subtraction diagnostics
- `sub-01_motor_template.png`
  - Average keypress-locked motor template from Action baseline block.
  - Should show motor-related waveform around keypress time.

- `sub-01_action_main_motor_subtracted.png`
  - Action main after motor subtraction and baseline correction.
  - Used to confirm corrected Action waveform shape per tone.

- `sub-01_diff_wave_motor_subtracted_per_tone.png`
- `sub-01_diff_wave_motor_subtracted_all.png`
  - Difference waves: `Action (motor-subtracted) - NoAction`.
  - These are the direct outputs for condition contrast.

### 13.2 Condition-level ERP summaries
- `sub-01_Action_Main_grand_average.png`
- `sub-01_NoAction_Main_grand_average.png`
  - Grand-average tone traces in each condition.
  - Compare N1/P2 windows visually after harmonized preprocessing.

- `sub-01_Action_vs_NoAction_Collapsed.png`
- `sub-01_Action_vs_NoAction_PerTone.png`
  - Side-by-side comparison plots; useful for quick communication.

### 13.3 Topographies
- `sub-01_Action_Main_topography.png`
- `sub-01_NoAction_Main_topography.png`
  - Spatial maps at peak latencies (P50/N1/P2).
  - Useful to check whether scalp distributions look physiologically plausible.

## 14. Practical "What To Conclude" For This Run
- The pipeline is now running correctly end-to-end for sample `sub-01`.
- Motor subtraction, matched baseline handling, and difference-wave generation are all functioning.
- The CSV and plots are internally consistent with the updated code path.
- Final scientific claims should be deferred until multi-subject/group analysis is run.
