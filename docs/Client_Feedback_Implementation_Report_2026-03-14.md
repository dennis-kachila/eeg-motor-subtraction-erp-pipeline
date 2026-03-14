# Client Feedback Implementation Report
**Project:** EEG Motor Subtraction ERP Pipeline
**Prepared for:** Client
**Date:** 14 March 2026
**Subject:** Implementation of five client-requested corrections and root-cause findings for the latency anomaly

---

## Summary

All five items raised in the client's feedback have been addressed. Items 1–5 are fully implemented and verified against the completed pipeline run. Item 6 (latency anomaly) has been fully diagnosed; the root cause is documented below and a targeted fix is ready to be applied before the next run of Step 7.

---

## Item 1 — Topoplots use the same scale for direct comparison

**Feedback:** Topoplots should share a common colour scale so they are directly comparable across conditions and blocks.

**Problem:** Each topoplot was previously rendered with an independently computed colour axis, meaning visual differences between plots could reflect scaling artefacts rather than genuine neural differences.

**Change made:**
A dedicated function `compute_shared_topo_clim` was added to `PrepareData_7_ComputeERPs.m` (line 133). Before any topoplot is drawn, this function pools the ERP data across all loaded datasets (action adaptation, action main, no-action adaptation, no-action main, and the action baseline motor template) and computes a symmetric colour limit:

```
shared_topo_clim = compute_shared_topo_clim({ac_adapt, ac_main, na_adapt, na_main, ac_baseline});
```

The computed limits are then passed as a shared argument (`shared_topo_clim`) to every call to `safe_plot_topo`, `plot_topo`, and `plot_motor_template_topography` (lines 73, 78, 94, 99, 126, 183, 184, 397, 403).

**Verified output (sub-01 run):**
```
Shared topography color limits: [-7.09, 7.09] uV
```
All six topoplots (P50, N1, P2 for Action and No-Action) used `[-7.09, 7.09] uV` as their colour axis throughout the run.

---

## Item 2 — Generate a topoplot for the motor template

**Feedback:** A topoplot should be generated for the motor template (baseline action block), so the spatial distribution of the motor artefact is visible.

**Problem:** No topoplot was previously produced for the baseline action block. This block represents the motor execution template used in the subtraction step, and its scalp topography was not being saved for visual inspection.

**Change made:**
A new function `plot_motor_template_topography` was added to `PrepareData_7_ComputeERPs.m` (line 163). It is called immediately after the shared colour limits are computed and before motor subtraction runs (line 35–37):

```matlab
if ~isempty(ac_baseline)
    plot_motor_template_topography(ac_baseline, Sub, fig_path, shared_topo_clim);
end
```

The function averages the baseline action ERP across all epochs, plots the resulting scalp topography using `topoplot`, applies the shared colour limits for comparability, and saves the figure.

**Verified output (sub-01 run):**
```
Saved: sub-01_motor_template_topography.png
```
The file is saved to the subject's figures directory under `derivatives/`.

---

## Item 3 — Filter before downsampling (not after)

**Feedback:** Filters must be applied before downsampling. The prior pipeline applied filtering after the resample step, which is incorrect both methodologically and from an anti-aliasing standpoint.

**Problem:** The original ordering in `PrepareData_1_Preprocessing.m` called `pop_resample` first and `ApplyFilters` second. Filtering after downsampling means the filter operates on already-aliased data, and the high-frequency content needed for correct anti-aliasing is irretrievably lost.

**Change made:**
The call order in `PrepareData_1_Preprocessing.m` was corrected (lines 174–195). The section now reads:

```matlab
% filter data — Client requirement: filter first, then downsample.
[EEG] = ApplyFilters(EEG, cfg);

% Downsample data
if cfg.runResample == 1
    fprintf('Resampling to %d Hz...\n', cfg.SamplingRate);
    [EEG, com] = pop_resample(EEG, cfg.SamplingRate);
    EEG = eegh(com, EEG);
end
```

`ApplyFilters.m` applies the low-pass filter first (Blackman-windowed FIR) and then the high-pass filter (Hamming-windowed FIR), both at the original raw sampling rate (1024 Hz), before the data is resampled down to 256 Hz.

**Verified in pipeline log:** The log for the completed full run confirms the sequence "Applying low-pass filter → Applying high-pass filter → Resampling to 256 Hz" for every session of every subject processed.

---

## Item 4 — ICA uses all channels (no default exclusions)

**Feedback:** ICA should run on all channels. Channels such as EOG and mastoids must not be excluded by default.

**Problem:** The previous ICA step excluded a predefined set of channels (EOG, mastoid/reference channels) before decomposition. For this paradigm, the client requires that the full channel set enters ICA so that all independent components, including ocular and muscular ones, are recovered and can be labelled and rejected individually by ICLabel.

**Change made:**
`PrepareData_3_RunICA.m` (lines 83–92) was updated so that when `cfg.ica_chans` is empty (the default), ICA is run on all available channels:

```matlab
% Client requirement: use all channels by default.
ica_chans = cfg.ica_chans;
if isempty(ica_chans)
    ica_chans = 1:EEG.nbchan;
    fprintf('Using all %d channels for ICA (default).\n', length(ica_chans));
end
```

The `ica_chans` vector is then passed directly to `pop_runica` via the `'chanind'` argument (line 150).

**Verified output (sub-01 run):**
```
Session ses-01 (no-action): Using all 67 channels for ICA (default).
Session ses-02 (action):    Using all 64 channels for ICA (default).
```
The channel count difference between sessions reflects the number of channels retained after bad-channel removal in each session, not any deliberate exclusion.

---

## Item 5 — No rereferencing after ICA

**Feedback:** The rereferencing step that occurred after ICA was included by mistake and should be removed.

**Problem:** A re-reference operation was being applied in `PrepareData_5_PostICAProcessing.m` after ICA cleaning. Post-ICA rereferencing is not part of the intended pipeline and can distort the cleaned signal.

**Change made:**
The rereferencing block in `PrepareData_5_PostICAProcessing.m` was disabled (lines 181–188). The section is preserved in the code for traceability but is unconditionally bypassed:

```matlab
% Final re-reference (disabled by client request)
reference_mode = 'skipped_by_design';
% ...
fprintf('Post-ICA re-reference is configured but skipped by client request.\n');
```

The post-ICA reference mode is recorded as `'skipped_by_design'` in `EEG.postica_reference_info.mode`, providing an auditable flag in the saved dataset.

**Verified in pipeline log:**
```
Post-ICA re-reference is configured but skipped by client request.
```
This message appeared for every session processed in the full run.

---

## Item 6 — Latency anomaly investigation

**Feedback:** Some latency values in the final output appear identical across conditions, which seems unlikely.

### Finding

All six N1 peak latency values in the output CSV (`sub-01_ERP_results.csv`) are identical at **82.03125 ms**:

| Condition | Tone | N1 Peak Latency (ms) |
|-----------|------|----------------------|
| NoAction | Low | 82.03125 |
| NoAction | Med | 82.03125 |
| NoAction | High | 82.03125 |
| Action | Low | 82.03125 |
| Action | Med | 82.03125 |
| Action | High | 82.03125 |

This is not a correct result. Two distinct mechanisms cause this, and they affect different conditions.

---

### Root Cause A — No-Action tones (window boundary issue)

The N1 search window is defined in `compute_N1_P2.m` (line 35) as **[80, 150] ms**. At the pipeline's output sampling rate of 256 Hz, the sample period is 3.90625 ms, so the first available sample at or after 80 ms is exactly **82.03125 ms**.

A diagnostic probe of the raw No-Action ERP waveforms at FCz confirmed that the true N1 trough for this subject lands on — or is indistinguishable from — the very first sample of the window:

```
NoAction Low:  min_time = 82.0312 ms,  min_val = -6.525 µV
NoAction Med:  min_time = 82.0312 ms,  min_val = -7.942 µV
NoAction High: min_time = 82.0312 ms,  min_val = -7.832 µV
```

The waveform is monotonically descending from 82.03 ms onward at this latency, meaning the true N1 peak likely occurs before 80 ms for this subject or the N1 window starts too late to capture the true onset.

---

### Root Cause B — Action tones (smoothing edge artefact)

The `robust_peak_latency` function in `compute_N1_P2.m` (lines 143–185) applies a `movmean` 5-point moving average before searching for the extremum. MATLAB's `movmean` uses a truncated (shorter) window at the edges of the signal, which can cause the first smoothed sample to appear more extreme than it truly is when the raw signal is relatively flat near the window start.

The diagnostic probe showed:

```
Action Low:  stored_lat = 82.0312 ms,  raw min_time = 85.9375 ms,  raw min_val = -0.343 µV
Action Med:  stored_lat = 82.0312 ms,  raw min_time = 85.9375 ms,  raw min_val = -0.759 µV
Action High: stored_lat = 82.0312 ms,  raw min_time = 85.9375 ms,  raw min_val = -0.341 µV
```

The raw N1 minimum for Action tones is at **85.9375 ms** (the second sample of the window), but smoothing forces the function to select `idx = 1` (the first sample). A quadratic sub-sample interpolation step exists in the function to refine latency estimates, but it is conditional on `idx > 1 AND idx < numel(seg)` — so when smoothing incorrectly selects the first sample, the interpolation is also skipped and the reported latency stays at the boundary value.

---

### Fix

Two targeted changes to `robust_peak_latency` in `compute_N1_P2.m` are required:

1. **Search the raw signal, not the smoothed signal.** Smoothing is appropriate for smoothing out noise but should not be the signal used to determine the extremum index. The fix is to find the extremum index on the raw signal and use smoothing only as a tie-breaker when multiple samples share the same value.

2. **Extend quadratic interpolation to boundary samples.** When the picked index is `idx == 1`, a one-sided (right-only) parabolic correction should still be possible using the first three samples. The current guard `idx > 1` unconditionally skips this.

**Additionally**, for No-Action tones, narrowing the N1-window start is worth considering (e.g., from 80 ms to 70 ms) to ensure the true pre-stimulus trough is not clipped. The window definition on line 35 of `compute_N1_P2.m` would change from `N1_window = [80 150]` to `N1_window = [70 150]`.

**Status:** The fix has been diagnosed and documented. It will be applied to `compute_N1_P2.m` and Step 7 will be rerun to regenerate the corrected CSV and ERP figures. Steps 1–6 (preprocessing, ICA, epoching) do not need to be rerun — their outputs in `derivatives/` are unaffected.

---

## Pipeline Run Verification

The full pipeline (Steps 1–7) was run end-to-end for subject sub-01 after all five corrections were applied. The run completed without errors and the log confirmed:

```
BASELINE PIPELINE RUN COMPLETE
Outputs saved under ...derivatives/
```

Key confirmed behaviours from the log:

| Check | Confirmed value |
|-------|----------------|
| Filter order | LP filter → HP filter → resample (all sessions) |
| ICA channel count (ses-01 no-action) | 67 channels |
| ICA channel count (ses-02 action) | 64 channels |
| Post-ICA rereference | Skipped by client request (all sessions) |
| Shared topoplot colour limits | [-7.09, 7.09] µV |
| Motor template topoplot | `sub-01_motor_template_topography.png` saved |

---

## Open Items

| # | Item | Status |
|---|------|--------|
| 1 | Shared topoplot colour scale | ✅ Complete |
| 2 | Motor template topoplot | ✅ Complete |
| 3 | Filter before downsample | ✅ Complete |
| 4 | ICA on all channels | ✅ Complete |
| 5 | No post-ICA rereferencing | ✅ Complete |
| 6 | N1 latency anomaly fix | ⚠ Root cause identified — fix pending Step 7 rerun |
