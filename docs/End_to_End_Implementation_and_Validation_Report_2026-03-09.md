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
