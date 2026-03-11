# Legacy vs Fixed Results Comparison (sub-01)

Date: 2026-03-11
Subject: sub-01
Comparison scope: Old pipeline code (legacy snapshot) vs current fixed pipeline outputs

## 1. Compared Output Locations
- Legacy run outputs: `eeglab_ERPs_legacy/sub-01/`
- Fixed pipeline outputs: `eeglab_ERPs/sub-01/`

Both runs used the same available sample dataset for `sub-01`.

## 2. Method Used
- Re-ran the legacy code snapshot and collected fresh outputs.
- Compared `sub-01_ERP_results.csv` row-by-row by key:
  - (`Condition`, `Tone`) in `{Action_Main, NoAction_Main} x {Low, Medium, High}`
- Computed fixed-minus-legacy deltas for:
  - `N1_Peak_Amp_uV`
  - `P2_Peak_Amp_uV`
  - `N1_Peak_Lat_ms`
  - `P2_Peak_Lat_ms`
  - `N_Epochs`
- Computed Action-minus-NoAction effect deltas in both versions and compared those.

## 3. Key Numeric Comparison
### 3.1 Condition-level change magnitude (max absolute delta across tones)

| Condition | Max ΔN1 (uV) | Max ΔP2 (uV) | Max ΔN1 Lat (ms) | Max ΔP2 Lat (ms) | Max ΔN Epochs |
|---|---:|---:|---:|---:|---:|
| Action_Main | 0.000001 | 0.000003 | 0 | 0 | 0 |
| NoAction_Main | 1.787926 | 1.787926 | 0 | 0 | 0 |

Interpretation:
- `Action_Main` metrics are effectively unchanged between legacy and fixed (numerical noise-level differences only).
- `NoAction_Main` amplitudes changed materially (up to ~1.79 uV), while latencies and epoch counts remained identical.

### 3.2 Per-tone Action-minus-NoAction effects
(Positive `DeltaN1` means Action N1 is less negative than NoAction N1.)

| Tone | Legacy DeltaN1 (Action-NoAction) uV | Fixed DeltaN1 (Action-NoAction) uV | Change in DeltaN1 (Fixed-Legacy) uV | Legacy DeltaP2 (Action-NoAction) uV | Fixed DeltaP2 (Action-NoAction) uV | Change in DeltaP2 (Fixed-Legacy) uV |
|---|---:|---:|---:|---:|---:|---:|
| Low | 2.475748 | 3.065002 | +0.589254 | 5.271908 | 5.861163 | +0.589255 |
| Medium | 2.268088 | 4.056015 | +1.787927 | 4.661815 | 6.449742 | +1.787927 |
| High | 3.250769 | 4.413981 | +1.163212 | 4.102922 | 5.266132 | +1.163210 |

Interpretation:
- The fixed pipeline increases Action-vs-NoAction separation in both N1 and P2 for all tones.
- The increase equals the NoAction-side correction magnitude (because Action is unchanged while NoAction amplitudes shifted).

## 4. Why These Differences Happened
This behavior is consistent with the implemented code changes and legacy behavior:

1. Legacy NoAction path used raw main data in key places
- Legacy execution log showed NoAction loaded from epoch path (`eeglab_epochs_per_block/..._main.set`) during comparison flow.
- In fixed code, NoAction main is explicitly preferred from processed baseline-corrected output (`..._main_bc.set`) when available.

2. Fixed pipeline enforces processing-state parity
- Fixed code aligns final comparison inputs to processed datasets for both conditions when available.
- This primarily affects `NoAction_Main` amplitudes in the final summary for this subject.

3. Action pathway remained stable between versions for this dataset
- Action metrics were nearly identical in legacy vs fixed CSV results.
- Therefore, observed effect-size changes are driven mainly by corrected NoAction handling.

4. Time-grid mismatch handling is hardened in fixed subtraction flow
- Legacy run emitted warning-based interpolation branch for Action/NoAction endpoint mismatch.
- Fixed code performs explicit harmonization to Action time grid for deterministic subtraction/comparison behavior.
- In this subject, latencies remained unchanged, indicating the harmonization stabilized behavior without shifting detected peak times.

## 5. Effect on Scientific Interpretation (sub-01)
- Direction of finding remains consistent: Action shows attenuated N1 relative to NoAction and larger P2 positivity.
- Magnitude of Action-vs-NoAction difference increased after fixes due to corrected NoAction processing parity.
- This is the expected effect of removing raw-vs-processed mixing and enforcing matched preprocessing in comparisons.

## 6. Practical Conclusion
For `sub-01`, the code fixes did not materially alter Action peak estimates, but they did correct NoAction handling, which increased and stabilized condition contrast metrics. This supports that the fixed pipeline is more internally consistent for Action-vs-NoAction inference.

## 7. Files Most Relevant to the Observed Effect
- `eeglab_ERP_analysis/PrepareData_7_ComputeERPs.m`
- `eeglab_ERP_analysis/plot_action_noaction_comparison.m`
- `eeglab_epochs/compare_N1_P2_amplitudes.m`
- `eeglab_ERP_analysis/subtract_motor_and_compute_difference.m`

## 8. Recommended Next Step
Repeat the same legacy-vs-fixed comparison for additional subjects to confirm that this NoAction-side correction effect generalizes beyond `sub-01`.
