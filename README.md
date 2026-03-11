# EEG Motor Subtraction ERP Pipeline

A MATLAB/EEGLAB pipeline for extracting Action/No-Action conditions, removing motor contamination from self-generated tone trials via **trial-level template subtraction**, computing auditory ERP components (P50/N1/P2), and generating comparison figures.

## Project Goal
Compare auditory ERP components between:
- **Action Main** — keypress-triggered tones; motor contamination removed before comparison
- **No-Action Main** — passive tone listening (no movement)

The key scientific objective is isolating the auditory N1 suppression signature (efference copy / predictive coding) by removing motor-related cortical activity from Action trials prior to N1/P2 analysis.

---

## Repository Structure

```text
.
├── eeglab_epochs/
│   ├── PrepareData_6_ExtractConditions.m   # Step 6 top-level: extract condition epochs
│   ├── extract_action_condition.m          # Extract Action condition epochs
│   ├── extract_noaction_condition.m        # Extract No-Action condition epochs
│   ├── compare_N1_P2_amplitudes.m          # Cross-condition amplitude comparison
│   └── run_epochs.m                        # Runner script for Step 6
│
├── eeglab_ERP_analysis/
│   ├── PrepareData_7_ComputeERPs.m         # Step 7 top-level: compute all ERPs
│   ├── subtract_motor_and_compute_difference.m  # Motor template subtraction (core)
│   ├── compute_N1_P2.m                     # N1/P2/P50 peak extraction
│   ├── plot_grand_average_waveforms.m      # Grand average ERP figures
│   ├── plot_scalp_topographies.m           # Scalp topo maps (P50, N1, P2)
│   ├── plot_action_noaction_comparison.m   # Side-by-side condition comparison plots
│   └── run_compute_ERPs.m                  # Runner script for Step 7
│
├── docs/
│   ├── Motor_Subtraction_Result_Analysis.md
│   ├── Full_Pipeline_Scripts_Review_Report.md
│   ├── ERP_vs_Trial_Level_Subtraction_Assessment.md
│   ├── Final_Motor_Subtraction_Audit_Report.md
│   ├── Implemented_Changes_Summary_2026-03-09.md
│   ├── How_To_Run_With_Sample_Datasets.md
│   ├── End_to_End_Implementation_and_Validation_Report_2026-03-09.md
│   ├── Client_Deliverables_Sub-01_2026-03-10.md
│   └── Legacy_vs_Fixed_Results_Comparison_Sub-01_2026-03-11.md
│
├── GetFilePathsAndInitializeToolboxes.m    # Path + toolbox initialisation helper
├── SaveMyData.m                            # EEGLAB dataset save helper
├── Project_Instructions.md                 # Original project specification
└── README.md
```

> **External toolbox:** EEGLAB is expected under `external/eeglab/` (not tracked by git).
> Download from [https://eeglab.org](https://eeglab.org) and place it there.

---

## Processing Flow

| Step | Script | Description |
|---|---|---|
| 6 | `PrepareData_6_ExtractConditions.m` | Epoch continuous post-ICA data; split into Action / No-Action × Adaptation / Main / Baseline blocks |
| 7a | `subtract_motor_and_compute_difference.m` | Build motor ERP template from baseline keypresses; trial-level subtraction; baseline correct both conditions; compute difference wave |
| 7b | `PrepareData_7_ComputeERPs.m` | Run subtraction, load results, compute N1/P2/P50 metrics, save CSV + figures |
| — | `compare_N1_P2_amplitudes.m` | Adaptation vs Main amplitude comparison per condition |
| — | `plot_action_noaction_comparison.m` | Side-by-side Action vs No-Action waveform comparison |

### Motor Subtraction Details
1. Average all baseline-block keypress epochs → motor ERP template (no tone, pure motor activity)
2. Shift Action Main epochs to keypress reference (−250 ms)
3. For each trial: `cleaned(t) = raw_trial(t) − motor_template(t)` (trial-level, sample-for-sample)
4. Shift cleaned epochs back to tone reference (+250 ms)
5. Apply matched baseline correction `[−200, 0 ms re tone]` to **both** Action and No-Action
6. Compute difference wave: `ΔW = Action_motor_subtracted − NoAction`

---

## Quick Start

### Prerequisites
- MATLAB R2020b or later
- EEGLAB (place in `external/eeglab/`)
- Epoched data in `eeglab_epochs_per_block/<subject>/` (`.set` files)

### Run Step 6 — Extract Conditions
```matlab
% Edit subjects list in run_epochs.m, then:
run_epochs
```

### Run Step 7 — Compute ERPs (includes motor subtraction)
```matlab
% Edit subjects list in run_compute_ERPs.m, then:
run_compute_ERPs
```

Outputs are written to `eeglab_ERPs/<subject>/` — figures, `.mat` results, and a summary CSV.

### Run for a single subject directly
```matlab
cfg = struct(); cfg.Pipeline = 1;
PrepareData_7_ComputeERPs('sub-01', cfg);
```

---

## Implemented Fixes (branch: `feature/motor-subtraction-fixes`)

A full audit and code review was performed and all identified issues are now resolved:

| Script | Fix |
|---|---|
| `subtract_motor_and_compute_difference.m` | Changed from ERP-level to **trial-level** subtraction; added explicit time-grid harmonisation via `interp1` |
| `PrepareData_7_ComputeERPs.m` | Subtraction now runs **before** metric computation; reloads motor-subtracted file; prefers processed `*_main_bc.set` for NoAction |
| `plot_action_noaction_comparison.m` | NoAction correctly loaded from processed baseline-corrected output (`*_main_bc.set`); Action loaded from motor-subtracted output |
| `compare_N1_P2_amplitudes.m` | Action loaded from `eeglab_ERPs/` (not epoch path); NoAction loaded from baseline-corrected output with raw fallback |
| `plot_scalp_topographies.m` | Field names corrected to `N1_peak_lat` / `P2_peak_lat` |
| `PrepareData_6_ExtractConditions.m` | Fixed cfg-aware block-count logging |

For full details see `docs/Implemented_Changes_Summary_2026-03-09.md` and `docs/Final_Motor_Subtraction_Audit_Report.md`.

### Validation (sub-01)
A legacy-vs-fixed comparison run was performed on `sub-01`. Key findings:
- **Action_Main** metrics: effectively unchanged (numerical noise < 1×10⁻⁵ µV)
- **NoAction_Main** amplitudes: corrected by up to **1.79 µV** due to processing-state parity fix
- All latencies and epoch counts: identical between legacy and fixed
- N1 suppression direction preserved; effect-size magnitude increased after fixes

See `docs/Legacy_vs_Fixed_Results_Comparison_Sub-01_2026-03-11.md` for the full numeric comparison.

---

## Notes
- Data files (`.set`, `.fdt`) are **not** tracked in this repository. Manage them according to your data-sharing policy.
- Sample datasets for `sub-01` should be placed in `eeglab_epochs_per_block/sub-01/`.
- All docs in `docs/` are Markdown; binary formats (`.docx`, `.xlsx`) are gitignored.

Done by Dennis Kachila, 2026-03-09
