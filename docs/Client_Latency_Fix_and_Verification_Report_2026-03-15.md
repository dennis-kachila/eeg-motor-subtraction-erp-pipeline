# Client Latency Fix and Verification Report
**Project:** EEG Motor Subtraction ERP Pipeline  
**Date:** 15 March 2026  
**Subject:** N1 latency anomaly fix, Step 7 rerun, and verified results

---

## Executive Summary

The repeated N1 latency issue identified in the ERP export has now been addressed. The Step 7 ERP computation was updated and rerun, and the regenerated results confirm that N1 peak latencies are no longer collapsing to the same value across all conditions.

The revised implementation now follows a clearer and more standard ERP peak-picking rule:

- **N1** is identified as the **absolute minimum** within the configured N1 search window.
- **P50** and **P2** are identified as the **absolute maximum** within their configured search windows.
- A **quadratic sub-sample refinement** is then applied to improve latency precision beyond the raw sampling interval.

This resolves the earlier edge-case behavior that was forcing multiple conditions to the same N1 latency value.

---

## Background

During review of the ERP outputs, all six N1 latency values for `sub-01` were previously reported as **82.03125 ms**. This pattern was unlikely to reflect the underlying physiology and indicated an issue in the peak-latency identification logic.

Investigation showed that two separate effects were contributing to the problem:

1. The N1 window started at **80 ms**, which was too late for some No-Action waveforms and effectively clipped the early part of the component.
2. The `movmean` smoothing used inside `robust_peak_latency` could bias peak selection toward the first sample in the window, especially at the edge of the segment. When that happened, the algorithm selected `idx = 1`, and quadratic interpolation was skipped.

---

## Changes Implemented

The changes were applied in [second_milestone/EEG_Processing/eeglab_ERP_analysis/compute_N1_P2.m](second_milestone/EEG_Processing/eeglab_ERP_analysis/compute_N1_P2.m).

### 1. N1 search window widened earlier

The N1 window start was moved from **80 ms** to **70 ms**:

- Previous: `N1_window = [80 150]`
- Updated: `N1_window = [70 150]`

This prevents early N1 minima from being clipped at the left edge of the search window.

### 2. Peak detection now uses the raw ERP signal

The main peak-selection rule was changed so that the algorithm identifies the component peak directly from the **raw waveform within the defined window**, rather than from the smoothed waveform.

This brings the implementation into better alignment with common ERP practice, where the component is defined as the **absolute extremum within a pre-specified latency range**.

### 3. Smoothing retained only as a tie-breaker

Smoothing is no longer used to decide the primary peak location. It is now used only in the uncommon case where multiple samples have effectively identical extremum values.

This preserves stability without letting smoothing distort peak selection at the window boundaries.

### 4. Boundary-aware quadratic interpolation added

The interpolation logic was extended so that it can still refine latency estimates when the detected peak occurs at the first or last sample of the local segment.

Previously, interpolation only ran when the peak index was strictly internal to the segment. That caused the reported latency to remain fixed at a boundary sample whenever the algorithm chose `idx = 1`.

### 5. In-code documentation added

The file now explicitly documents the component-identification rules so that the implementation is transparent and auditable:

- **N1:** absolute minimum within window
- **P50/P2:** absolute maximum within window
- **Latency refinement:** local quadratic fit for sub-sample precision

---

## Step 7 Rerun

After implementing the changes, **Step 7 (ERP computation)** was rerun for `sub-01`.

The updated results were written to:

[second_milestone/derivatives/eeglab_ERPs/sub-01/sub-01_ERP_results.csv](second_milestone/derivatives/eeglab_ERPs/sub-01/sub-01_ERP_results.csv)

The regenerated file timestamp confirms a fresh rerun on **15 March 2026 at 14:41:12**.

---

## Verified N1 Results

The rerun confirms that the N1 latencies are now distributed across conditions and tones, rather than collapsing to a single repeated value.

### Updated N1 peak latencies

| Subject | Condition | Tone | Verified N1 Peak Latency (ms) |
|---------|-----------|------|-------------------------------|
| sub-01 | NoAction_Main | Low | 82.14 |
| sub-01 | NoAction_Main | Medium | 77.08 |
| sub-01 | NoAction_Main | High | 82.83 |
| sub-01 | Action_Main | Low | 86.34 |
| sub-01 | Action_Main | Medium | 85.06 |
| sub-01 | Action_Main | High | 87.55 |

### Interpretation

These values are now consistent with the expected N1 range described in the literature, typically around **70–120 ms** depending on paradigm and preprocessing choices.

The important outcome is that:

- the values are **no longer artificially identical**, and
- the distribution is now **physiologically plausible** and aligned with the intended detection logic.

---

## Additional Observation

Most P2 latency values in the rerun fall near **152–156 ms**, which is broadly consistent with expectation. One value, however, remains relatively late:

- `NoAction_Main / Low` P2 latency = **273.44 ms**

This is still inside the current configured P2 window of **150–275 ms**, but it is later than the more typical literature range of approximately **150–250 ms**.

This does not affect the N1 fix itself, but it suggests that the P2 upper bound may be worth tightening in a future refinement if stricter literature alignment is desired.

---

## Conclusion

The N1 latency anomaly has been successfully resolved.

### Completed

- Root cause identified
- Peak-picking logic updated
- N1 window adjusted to avoid early clipping
- Boundary interpolation added
- Step 7 rerun completed
- Output CSV verified

### Outcome

The regenerated ERP results show a realistic spread of N1 latencies across conditions and tones, and the implementation now follows a more transparent, standard ERP peak-selection rule based on window-constrained absolute extrema with sub-sample refinement.

If needed for final submission, the next optional refinement would be to narrow the P2 window upper bound from **275 ms** to **250 ms** and rerun Step 7 again for stricter conformity with the literature.