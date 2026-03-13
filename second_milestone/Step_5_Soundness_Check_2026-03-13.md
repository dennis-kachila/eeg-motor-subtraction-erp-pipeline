# Step 5 Soundness Check (2026-03-13)

## Scope
- Step: PrepareData_5_PostICAProcessing
- Runner: EEG_Processing/eeglab_post_ICA/run_post_ICA.m
- Subject checked: sub-01
- Sessions checked:
  - _ses-01_task-no-action_eeg
  - _ses-02_task-action_eeg

## Runtime Result
- Pipeline run status: success
- Sessions processed successfully: 2
- Sessions with errors: 0

## Output Verification
- Output folder: second_milestone/derivatives/eeglab_post_ICA/sub-01
- Files present:
  - sub-01_ses-01_task-no-action_eeg_post_ICA.set/.fdt
  - sub-01_ses-02_task-action_eeg_post_ICA.set/.fdt

## Soundness Notes
1. Epoch rejection setting is OFF for Step 5 in pipeline config, and data is continuous. This is expected and consistent.
2. Channel interpolation setting is OFF for Step 5 in pipeline config. This is expected and consistent.
3. Final re-reference requested channels are "Mastoid Left" and "Mastoid Right", but these channels are not present in the IC-rejected inputs for either session.
4. Step 5 now applies an automatic average-reference fallback when requested mastoid channels are unavailable.

## Interpretation
- Step 5 is technically stable and reproducible for current inputs.
- Final rereference is always applied: mastoid rereference when available, otherwise average-reference fallback.

## Recommended Follow-up
- For future datasets, consider preserving mastoid-equivalent channels and consistent labels earlier in the pipeline if strict mastoid rereference is required by protocol.
