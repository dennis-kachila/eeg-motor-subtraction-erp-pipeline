# Step 4 ICLabel Root Cause And Follow-Up

## Root Cause Identified

The Step 4 ICLabel failure is caused by missing channel typing in the ICA datasets.

Inspection of a current ICA dataset showed:

- `EEG.chanlocs.type` is effectively empty for all channels.
- `EEG.icachansind` includes all channels.
- Non-scalp channels are included in ICA, including labels such as `Horizontal Left` and `Down Vertical Le`.

Because ICLabel expects a valid scalp montage for feature extraction, this can cause the error:

- `Matrix dimensions must agree.`

## Why This Matters

If ICA includes non-scalp channels and ICLabel cannot build a consistent scalp feature representation, Step 4 may complete without crashing but reject zero components. That is technically stable but methodologically incomplete.

## Follow-Up

1. Add a deterministic scalp-channel fallback in Step 3 when `EEG.chanlocs.type` is missing.
2. Add a scalp-only ICLabel fallback path in Step 4 for existing ICA outputs.
3. Re-run Step 4 and confirm ICLabel classification succeeds on both sessions.
4. If Step 4 succeeds, continue to Step 5 using the corrected IC-rejected datasets.