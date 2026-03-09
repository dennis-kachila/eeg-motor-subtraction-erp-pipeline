# EEG Motor Subtraction ERP Pipeline

A MATLAB/EEGLAB pipeline for extracting Action/No-Action conditions, removing motor contamination from self-generated tone trials, computing ERP components (P50/N1/P2), and generating comparison figures.

## Suggested GitHub Repository Name
`eeg-motor-subtraction-erp-pipeline`

Alternative names:
- `action-noaction-erp-analysis`
- `motor-template-subtraction-eeg`
- `eeglab-auditory-erp-motor-correction`

## Project Goal
Compare auditory ERP components between:
- `Action Main` (keypress-triggered tones; motor-contaminated before correction)
- `No-Action Main` (passive tone listening)

Key scientific requirement:
- Remove motor-related cortical activity from Action Main prior to N1/P2 comparison.

## Repository Structure
```text
.
|-- eeglab_epochs/
|   |-- PrepareData_6_ExtractConditions.m
|   |-- extract_action_condition.m
|   |-- extract_noaction_condition.m
|   |-- compare_N1_P2_amplitudes.m
|
|-- eeglab_ERP_analysis/
|   |-- PrepareData_7_ComputeERPs.m
|   |-- subtract_motor_and_compute_difference.m
|   |-- compute_N1_P2.m
|   |-- plot_grand_average_waveforms.m
|   |-- plot_scalp_topographies.m
|   |-- plot_action_noaction_comparison.m
|
|-- docs/
|   |-- Motor_Subtraction_Result_Analysis.md
|   |-- Full_Pipeline_Scripts_Review_Report.md
|   |-- ERP_vs_Trial_Level_Subtraction_Assessment.md
|   |-- Final_Motor_Subtraction_Audit_Report.md
|
|-- Project_Instructions.md
|-- README.md
```

## Processing Flow
1. Extract condition-specific epochs from post-ICA continuous data.
2. Build motor template from Action Baseline keypress-locked epochs.
3. Shift Action Main epochs to keypress reference (`-250 ms`).
4. Subtract motor component.
5. Shift cleaned data back to tone reference (`+250 ms`).
6. Apply matched baseline correction (`[-200, 0] ms re tone`) to Action and No-Action.
7. Compute ERP metrics and create plots.

## Current Audit Status
A full review has been completed and documented in `docs/`.

Recent implemented fixes summary:
- `docs/Implemented_Changes_Summary_2026-03-09.md`
- `docs/How_To_Run_With_Sample_Datasets.md`
- `docs/End_to_End_Implementation_and_Validation_Report_2026-03-09.md`

Main issues identified:
- Some scripts mix raw and processed datasets in comparisons.
- One script uses the wrong folder for motor-subtracted file loading.
- One plotting script has field-name mismatches.
- Trial-level subtraction is recommended as the primary analysis path.

## Next Implementation Step
Create and work from a dedicated branch for fixes, for example:
- `feature/motor-subtraction-fixes`

## Notes
- This project assumes EEGLAB and required toolbox/path helpers are available in your MATLAB environment.
- Data files (`.set`) are not included in this repository snapshot and should be managed according to your data-sharing policy.
