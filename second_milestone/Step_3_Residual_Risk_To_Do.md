# Step 3 Residual Risk And Resolution

## Current Status

The main Step 3 runtime failure has been resolved.

`PrepareData_3_RunICA.m` now computes the effective ICA component limit from the rank of the selected ICA channels, not from the rank of the full dataset. This prevents invalid `pca` values when ICA is run on a scalp-only channel subset.

The script was validated by running Step 3 directly for both available sessions of `sub-01`, and both ICA outputs were regenerated successfully.

## Remaining Methodology Risk

The only remaining review risk is channel typing quality.

Step 3 still prefers channels with `EEG.chanlocs.type == 'EEG'`. If channel typing is missing, the code now falls back to a deterministic scalp-channel inference helper before using all channels.

That means the pipeline is now protected against the fresh-run crash, but methodological quality still depends on reasonable channel metadata or label-based scalp inference.

## Validation Outcome

1. The previous Step 3 `runica(): pca value must be in range ...` failure no longer occurs.
2. Fresh ICA outputs were regenerated for both sessions of `sub-01`.
3. Steps 4 to 7 were rerun successfully using the regenerated ICA outputs.

## Reference

- File: `second_milestone/EEG_Processing/eeglab_ICA/PrepareData_3_RunICA.m`
- Relevant logic: ICA channel selection and component-count block before `pop_runica`.