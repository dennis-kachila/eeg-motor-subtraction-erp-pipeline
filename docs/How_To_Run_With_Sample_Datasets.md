# How To Run In MATLAB Environment

Date: 2026-03-09

## Summary
This guide shows how to run the project in MATLAB using the provided sample data and current codebase.

Validated path:
1. Add repo + EEGLAB to MATLAB path.
2. Place required epoched `.set/.fdt` pairs in `eeglab_epochs_per_block/sub-01/`.
3. Run `PrepareData_7_ComputeERPs('sub-01', cfg)`.
4. Verify output files under `eeglab_ERPs/sub-01/`.

## Prerequisites
1. MATLAB is installed and callable.
2. EEGLAB is available (repo currently uses `external/eeglab`).
3. Required helper files exist in repo root:
- `GetFilePathsAndInitializeToolboxes.m`
- `SaveMyData.m`

## 1) Start MATLAB in repository root
Open MATLAB with current folder set to this repository root:
- `C:\Users\USER\Downloads\Documents\eeg-motor-subtraction-erp-pipeline`

## 2) Add paths in MATLAB
Run:

```matlab
addpath(genpath(pwd));
addpath(genpath(fullfile(pwd, 'external', 'eeglab')));
```

Optional quick check:

```matlab
which eeglab
which pop_loadset
which topoplot
```

## 3) Prepare Step 7 inputs (`.set` + `.fdt`)
`PrepareData_7_ComputeERPs` loads epoched inputs from:
- `eeglab_epochs_per_block/sub-01/`

Required files (both `.set` and `.fdt` companions):
- `sub-01_ses-01_task-no-action_eeg_adaptation.*`
- `sub-01_ses-01_task-no-action_eeg_main.*`
- `sub-01_ses-02_task-action_eeg_adaptation_action.*`
- `sub-01_ses-02_task-action_eeg_main_action.*`
- `sub-01_ses-02_task-action_eeg_baseline_action.*`

If needed, copy from `sample_datasets/epoched datasets/` into `eeglab_epochs_per_block/sub-01/`.

Note:
- Keep `.set` and `.fdt` base names matched exactly.
- Do not rename only `.set` without `.fdt`.

## 4) Run Step 7 (ERP + motor subtraction)
In MATLAB:

```matlab
cfg = struct();
cfg.Pipeline = 1;
PrepareData_7_ComputeERPs('sub-01', cfg);
```

## 5) Verify outputs
Check these outputs in `eeglab_ERPs/sub-01/`:

- `sub-01_ses-02_task-action_eeg_main_action_motor_subtracted.set`
- `sub-01_ses-01_task-no-action_eeg_main_bc.set`
- `sub-01_difference_wave_motor_subtracted.mat`
- `sub-01_ERP_results_action.mat`
- `sub-01_ERP_results_noaction.mat`
- `sub-01_ERP_results.csv`
- `sub-01_ERP_results.xlsx`

And figures in `eeglab_ERPs/sub-01/figures/`, including:
- motor template
- action motor-subtracted ERP
- difference wave (per-tone and all-tone)
- Action vs NoAction comparison figures

## 6) What `Low`, `Medium`, and `High` Mean
You will see these labels in plot legends and in `sub-01_ERP_results.csv` under `Tone`.

- `Low` = epochs with event marker `Tone_Low`
- `Medium` = epochs with event marker `Tone_Med`
- `High` = epochs with event marker `Tone_High`

In plain language, these are the three auditory stimulus categories (low-, mid-, and high-frequency tones) defined by the experiment.

Important note:
- This repository uses category labels, not explicit numeric frequencies.
- Exact Hz values come from the acquisition/paradigm configuration used during data collection, not from these analysis scripts.

## Optional: Run from terminal (PowerShell)
From repo root:

```powershell
matlab -batch "addpath(genpath(pwd)); addpath(genpath(fullfile(pwd,'external','eeglab'))); cfg=struct(); cfg.Pipeline=1; PrepareData_7_ComputeERPs('sub-01', cfg);"
```

## Optional: Full extraction + ERP flow
If your environment includes the full project helper stack and path config for continuous input:
1. Run extraction (Step 6) from continuous files.
2. Run ERP computation (Step 7).

In this repo snapshot, Step 7 with prepared epoched inputs is the recommended validated path.

## Troubleshooting
- `... .fdt not found`:
  Ensure `.fdt` companion exists next to `.set` with same base name.
- `eeglab not found`:
  Add `external/eeglab` to MATLAB path.
- Missing helper function errors:
  Ensure repository root is on MATLAB path (`addpath(genpath(pwd))`).

## Timing Note (Observed 4 ms Difference)
During validation, a small Action vs NoAction endpoint mismatch was observed in some runs:
- Action time axis: `[-449, 641] ms`
- NoAction time axis: `[-449, 637] ms`

Why this happens:
- EEGLAB epoch boundary rounding and discontinuity handling can produce a 1-sample endpoint difference after epoching/baseline operations.
- At `256 Hz`, one sample is `~3.906 ms`, which appears as approximately `4 ms` in logs.

How it is handled in code:
- `subtract_motor_and_compute_difference.m` now explicitly harmonizes NoAction to the Action time grid before difference-wave computation.
- This removes fragile branch behavior and keeps subtraction/comparison deterministic.

Interpretation:
- This is a sample-grid alignment detail, not a conceptual subtraction error.
- The pipeline now handles it intentionally and continues to produce valid output artifacts.
