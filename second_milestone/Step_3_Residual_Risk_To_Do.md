# Step 3 Residual Risk To Do

## Residual Risk

The only meaningful review risk is channel typing.

Step 3 tries to restrict ICA to channels with `EEG.chanlocs.type == 'EEG'` in `PrepareData_3_RunICA.m`.

If channel types are missing in the cleaned datasets, the code falls back to all channels. That could include non-scalp channels in ICA. The code will not crash, but it could reduce methodological quality.

This has not yet been verified against the current `_clean` datasets because Step 3 was reviewed statically and not executed.

## Follow-Up To Do

1. Inspect at least one current `_clean` dataset and verify whether `EEG.chanlocs.type` is populated.
2. Confirm that only scalp EEG channels are included in the ICA channel list.
3. If channel typing is missing, add a deterministic fallback that excludes EOG, mastoids, and other non-scalp channels before ICA.

## Reference

- File: `second_milestone/EEG_Processing/eeglab_ICA/PrepareData_3_RunICA.m`
- Relevant logic: channel selection near the ICA setup block.