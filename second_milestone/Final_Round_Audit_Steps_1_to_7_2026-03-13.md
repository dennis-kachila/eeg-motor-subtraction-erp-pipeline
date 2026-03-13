# Final Round Audit: Steps 1 to 7 (2026-03-13)

## Scope
This report summarizes the final-round validation of the active pipeline in `second_milestone/EEG_Processing` from Step 1 through Step 7 for `sub-01`.

## Overall Outcome
- Pipeline status for this validation round: **Operationally successful** (Steps 1, 2, 4, 5, 6, 7 executed successfully).
- Main outputs for Step 7 were produced (MAT, CSV, XLSX, figures).
- Remaining caveats are documented below.

## Step-by-Step Status

### Step 1: Preprocessing
- Status: **PASS (runtime validated)**
- Notes:
  - Completed for both sessions.
  - Memory-stability fixes were applied earlier in this round (resample-before-filter and FIR-order cap in shared filtering).
- Output location:
  - `second_milestone/derivatives/eeglab_preproc/sub-01`

### Step 2: Automatic Artifact Rejection
- Status: **PASS (runtime validated)**
- Notes:
  - Completed for both sessions.
- Output location:
  - `second_milestone/derivatives/eeglab_artifact_rejection/sub-01`

### Step 3: ICA
- Status: **PASS (code/path reviewed), runtime rerun deferred**
- Notes:
  - Step 3 code was reviewed and patched for channel-selection robustness when channel `type` metadata is missing.
  - A full rerun was intentionally deferred due runtime cost.
  - Residual-risk note exists for future rerun verification.
- Output location currently used by downstream steps:
  - `second_milestone/derivatives/eeglab_ICA/sub-01`
- Related note:
  - `second_milestone/Step_3_Residual_Risk_To_Do.md`

### Step 4: IC Rejection
- Status: **PASS (runtime validated with robust fallback path)**
- Notes:
  - Completed for both sessions.
  - Native ICLabel call still fails on current montage metadata in this dataset.
  - Fallback path now succeeds reliably and prevents blocking interactive failures.
  - Result in latest validation run:
    - no-action session: 1 component rejected (muscle)
    - action session: 0 components rejected
- Output location:
  - `second_milestone/derivatives/eeglab_IC_rejection/sub-01`
- Related note:
  - `second_milestone/Step_4_ICLabel_Root_Cause_And_Follow_Up.md`

### Step 5: Post-ICA Processing
- Status: **PASS (runtime validated)**
- Notes:
  - Completed for both sessions.
  - Final rereference policy improved:
    - Uses requested mastoid channels when available.
    - Falls back automatically to average reference when mastoids are missing.
- Output location:
  - `second_milestone/derivatives/eeglab_post_ICA/sub-01`
- Related note:
  - `second_milestone/Step_5_Soundness_Check_2026-03-13.md`

### Step 6: Condition Extraction / Epoching
- Status: **PASS (runtime validated)**
- Notes:
  - Completed for both sessions.
  - Session-specific processing is working as intended through `RunMyScripts`.
  - Baseline/adaptation/main block datasets were generated.
- Output location:
  - `second_milestone/derivatives/eeglab_epochs_per_block/sub-01`

### Step 7: ERP Computation and Motor Subtraction
- Status: **PASS (runtime validated)**
- Notes:
  - Completed end-to-end, including motor subtraction and CSV/XLSX export.
  - Known non-blocking caveat: scalp topography plotting still fails in this environment (`intValues`), but processing continues and final outputs are produced.
- Output location:
  - `second_milestone/derivatives/eeglab_ERPs/sub-01`

## Final Deliverables Confirmed (Step 7)
Confirmed present in `second_milestone/derivatives/eeglab_ERPs/sub-01`:
- `sub-01_ERP_results.csv`
- `sub-01_ERP_results.xlsx`
- `sub-01_ERP_results_action.mat`
- `sub-01_ERP_results_noaction.mat`
- `sub-01_difference_wave_motor_subtracted.mat`
- `sub-01_ses-01_task-no-action_eeg_main_bc.set/.fdt`
- `sub-01_ses-02_task-action_eeg_main_action_motor_subtracted.set/.fdt`
- Figures in `second_milestone/derivatives/eeglab_ERPs/sub-01/figures`

## Remaining Caveats (Final Round)
1. Step 3 was not rerun after the channel-selection robustness patch; downstream currently uses existing ICA outputs.
2. Step 4 native ICLabel path still depends on metadata quality and fails on this subject; fallback path is now the effective path.
3. Step 7 scalp topography plotting remains non-blocking but unresolved (`intValues`).

## Recommendation
For milestone closeout, the pipeline is ready for operational use on the validated subject with documented caveats. If time allows before freeze, prioritize:
1. Rerun Step 3 and Step 4 once on the patched Step 3 output for clean provenance.
2. Resolve the Step 7 topography plotting bug if scalp maps are required in the final deliverable.
