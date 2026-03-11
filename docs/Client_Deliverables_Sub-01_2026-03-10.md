# Client Deliverables - Motor Subtraction ERP Pipeline

Date: 2026-03-10
Project: EEG Motor Subtraction ERP Pipeline
Subject package: `sub-01`

## Delivery Summary
This document accompanies the submitted `sub-01` results package and summarizes:
1. The corrected scripts delivered.
2. What was wrong and what was changed.
3. The example outputs generated for one subject.
4. Additional pipeline review findings.

The pipeline has been re-run and validated on `sub-01`, and the output artifacts were generated successfully.

## Deliverable 1: Corrected Scripts
The following scripts were updated as part of the fix set:

- `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m`
- `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m`
- `eeglab_ERP_analysis/plot_action_noaction_comparison.m`
- `eeglab_epochs/compare_N1_P2_amplitudes.m`
- `eeglab_ERP_analysis/plot_scalp_topographies.m`
- `eeglab_epochs/PrepareData_6_ExtractConditions.m`

Primary correction target:
- `subtract_motor_and_compute_difference.m` was corrected and hardened to ensure reliable time alignment, subtraction behavior, and deterministic difference-wave computation.

## Deliverable 2: Detailed Problem Analysis and Exact Changes
### 2.1 Root-cause summary
The primary issue was not a single syntax/runtime failure. The core subtraction flow existed, but downstream integration inconsistencies caused scientifically unreliable condition comparisons.

Most important root causes:
- Some comparison scripts mixed processed Action data with raw NoAction data.
- One script loaded motor-subtracted Action from the wrong folder.
- Wrapper orchestration allowed metrics/plots to be generated before final harmonized data selection.
- One plotting script expected field names that did not match producer outputs.
- Small Action/NoAction endpoint differences (1 sample) could produce fragile subtraction branches without explicit grid harmonization.

### 2.2 Exact edits by file
This section lists concrete file-level edits and their purpose.

#### A) `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m`
Problem addressed:
- Subtraction behavior and cross-condition comparison required deterministic, trial-preserving logic and robust handling of tiny time-grid mismatches.

Exact edits:
- Implemented trial-level subtraction explicitly:
  - `template_3d = repmat(motor_template, [1 1 EEG_kp_bc.trials]);`
  - `EEG_subtracted.data = EEG_kp_bc.data - template_3d;`
- Preserved a collapsed signal from cleaned trial data for downstream grand-average visualization:
  - `EEG_subtracted.collapsed_erp_clean = mean(EEG_subtracted.data, 3);`
- Applied final tone-locked baseline correction to both conditions in one location using the same target window (`[-200, 0] ms`) with per-dataset clamping.
- Saved processed outputs to ERP output path:
  - Action: `*_main_action_motor_subtracted.set/.fdt`
  - NoAction: `*_main_bc.set/.fdt`
- Added deterministic Action/NoAction time-grid harmonization before subtraction/difference wave:
  - If time vectors differ, NoAction is interpolated to Action grid using `interp1(..., 'linear', 'extrap')`.
- Computed per-tone and collapsed difference waves from harmonized data and saved:
  - `sub-01_difference_wave_motor_subtracted.mat`

Why this matters:
- Preserves trial structure.
- Prevents edge-case subtraction instability when one condition is shorter by one sample.
- Ensures Action and NoAction are compared on a common grid.

#### B) `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m`
Problem addressed:
- Orchestration risk of mismatched processing states in final metrics/plots.

Exact edits:
- Runs motor subtraction early in the pipeline flow when Action main + baseline are available.
- Reloads motor-subtracted Action main from ERP output path after subtraction:
  - `<out_path>/<Sub>_ses-02_task-action_eeg_main_action_motor_subtracted.set`
- Prefers processed NoAction main from ERP output path when available:
  - `<out_path>/<Sub>_ses-01_task-no-action_eeg_main_bc.set`
- Continues with fallback behavior if processed files are unavailable, but now defaults to matched processed datasets.
- Keeps final result export consolidated in ERP output folder (`.mat`, `.csv`, `.xlsx`, figures).

Why this matters:
- Reduces the risk of plotting/quantifying Action from processed data against raw NoAction.

#### C) `eeglab_ERP_analysis/plot_action_noaction_comparison.m`
Problem addressed:
- Comparison plot input inconsistency.

Exact edits:
- NoAction main file selection now prefers processed baseline-corrected main in ERP folder:
  - first: `<out_path>..._main_bc.set`
  - fallback: `<epo_path>..._main.set`
- Action file selection now prefers motor-subtracted Action main in ERP folder:
  - first: `<out_path>..._main_action_motor_subtracted.set`
  - fallback: raw `<epo_path>..._main_action.set`
- Retained collapsed and per-tone plotting logic, but now driven by corrected file-priority rules.

Why this matters:
- Ensures visual comparison figures are based on matched processing state wherever available.

#### D) `eeglab_epochs/compare_N1_P2_amplitudes.m`
Problem addressed:
- Wrong path for Action motor-subtracted load and inconsistent NoAction source.

Exact edits:
- Changed Action main load priority to ERP output path for motor-subtracted data:
  - first: `<out_path>..._main_action_motor_subtracted.set`
  - fallback: raw `<epo_path>..._main_action.set`
- Changed NoAction main load priority to ERP output path baseline-corrected data:
  - first: `<out_path>..._main_bc.set`
  - fallback: raw `<epo_path>..._main.set`
- Updated header description to match implemented behavior:
  - from inferential/paired-test wording to descriptive within-subject summary wording.

Why this matters:
- Prevents missing or wrong-input Action main files in downstream amplitude summary.
- Improves parity between compared conditions.

#### E) `eeglab_ERP_analysis/plot_scalp_topographies.m`
Problem addressed:
- Producer/consumer schema mismatch.

Exact edits:
- Updated expected latency fields to match `compute_N1_P2.m` outputs:
  - `results.Central.N1_peak_lat`
  - `results.Central.P2_peak_lat`

Why this matters:
- Removes runtime mismatch and ensures topographies are sampled at intended peak latencies.

#### F) `eeglab_epochs/PrepareData_6_ExtractConditions.m`
Problem addressed:
- Runtime messaging did not clearly reflect configured-vs-default epoch windows.

Exact edits:
- Replaced hardcoded/ambiguous window status text with cfg-aware logging:
  - if `cfg.epoch_tmin/epoch_tmax` present, print those values.
  - otherwise print that extraction defaults are used.

Why this matters:
- Improves reproducibility traceability in logs and reduces confusion during reruns.

### 2.3 Before/After behavioral summary
Before fixes:
- High risk of processed-vs-raw mixing in Action vs NoAction outputs.
- Potential wrong-path load for motor-subtracted Action in one analysis script.
- Field mismatch risk in topography plotting.
- Time-axis mismatch handling could be fragile in edge cases.

After fixes:
- Processed file preference standardized across comparison pathways.
- Action motor-subtracted and NoAction baseline-corrected outputs are consistently consumed when present.
- Topography field mapping is aligned with metric producer schema.
- Difference-wave computation is stabilized with explicit time-grid harmonization.

Net result:
- `sub-01` end-to-end outputs are internally consistent with the corrected processing logic and are reproducibly generated under the expected output structure.

## Deliverable 3: Example Outputs From One Subject (`sub-01`)
The following expected outputs were generated under `eeglab_ERPs/sub-01/`:

### Core data outputs
- `eeglab_ERPs/sub-01/sub-01_ses-02_task-action_eeg_main_action_motor_subtracted.set`
- `eeglab_ERPs/sub-01/sub-01_ses-02_task-action_eeg_main_action_motor_subtracted.fdt`
- `eeglab_ERPs/sub-01/sub-01_ses-01_task-no-action_eeg_main_bc.set`
- `eeglab_ERPs/sub-01/sub-01_ses-01_task-no-action_eeg_main_bc.fdt`
- `eeglab_ERPs/sub-01/sub-01_difference_wave_motor_subtracted.mat`
- `eeglab_ERPs/sub-01/sub-01_ERP_results.csv`
- `eeglab_ERPs/sub-01/sub-01_ERP_results.xlsx`

### Required example figures
- Motor template:
  - `eeglab_ERPs/sub-01/figures/sub-01_motor_template.png`
- Motor-subtracted Action ERP:
  - `eeglab_ERPs/sub-01/figures/sub-01_action_main_motor_subtracted.png`
- No-Action ERP:
  - `eeglab_ERPs/sub-01/figures/sub-01_NoAction_Main_grand_average.png`
- Difference wave:
  - `eeglab_ERPs/sub-01/figures/sub-01_diff_wave_motor_subtracted_per_tone.png`
  - `eeglab_ERPs/sub-01/figures/sub-01_diff_wave_motor_subtracted_all.png`

Additional comparison views included:
- `eeglab_ERPs/sub-01/figures/sub-01_Action_vs_NoAction_Collapsed.png`
- `eeglab_ERPs/sub-01/figures/sub-01_Action_vs_NoAction_PerTone.png`

## Deliverable 4 (Optional): Code Review Notes
Short code-review findings and broader pipeline audit notes are included in:

- `docs/Full_Pipeline_Scripts_Review_Report.md`
- `docs/Final_Motor_Subtraction_Audit_Report.md`
- `docs/Motor_Subtraction_Result_Analysis.md`
- `docs/ERP_vs_Trial_Level_Subtraction_Assessment.md`

These documents capture high-impact logic risks identified during review and the corrective actions applied.

## Validation Statement
`sub-01` was processed end-to-end with the corrected pipeline, and deliverable outputs were generated in the expected locations. The resulting figures and tables support that motor subtraction and Action-vs-NoAction comparison flow are functioning as intended for this sample subject.

## Notes for Client Review
- `Low`, `Medium`, and `High` in tables/plots correspond to tone event categories `Tone_Low`, `Tone_Med`, and `Tone_High`.
- N1 and P2 metrics are reported using the project windows:
  - N1: `80-150 ms`
  - P2: `150-275 ms`
- This package is a subject-level validation package (`sub-01`). Group-level inferential conclusions should be based on multi-subject runs.
