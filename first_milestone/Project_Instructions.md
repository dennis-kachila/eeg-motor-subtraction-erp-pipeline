Project Overview
We have a MATLAB/EEGLAB pipeline that extracts experimental conditions, performs motor potential removal via template subtraction, computes auditory event-related potentials (ERPs), and produces figures and summary statistics across subjects. The pipeline runs without crashing but the motor subtraction output is not producing the expected results. We need an experienced EEG signal processing specialist to review the code logic, identify what is going wrong, and deliver a corrected, tested pipeline.

Experimental Design
No-Action Session 
The participant sits passively and listens to tones (Low, Medium, or High frequency) which appear 250 ms after the dissapereance of a fixation cross. There are no motor responses. The session is divided into an Adaptation block (first 100 tone epochs) and a Main block (all remaining epochs) where they perform another task. All epochs are time-locked to tone onset.

Action Session
The participant presses a key of their own volition to produce a tone 250 ms after. Each trial therefore contains a voluntary keypress. The session has three parts:

•	Baseline Block – the participant presses keys with no tones playing. These keypress-locked epochs contain pure motor brain activity (MRCP, motor N1) with no auditory response. This block provides the motor template for subtraction.
•	Adaptation Block – the participant presses keys to produce a tone 250 ms after.
•	Main Block – all remaining tone trials, tone-locked. The participants press the key to produce a tone 250 ms after and perform another task.This is the primary dataset for analysis. Also contains both motor and auditory activity and requires motor subtraction before N1/P2 can be measured.

The Motor Subtraction Problem
The scientific goal is to compare the auditory N1 (80–150 ms post-tone) and P2 (150–275 ms post-tone) components between the Action Main block and the No-Action Main block. Because the participant presses a key 250 ms before every tone in the Action session, every tone-locked epoch in that block contains motor-related cortical activity (MRCP, motor N1) that directly overlaps the N1 and P2 windows. This motor contamination must be removed before any valid comparison with the No-Action condition is possible.

The intended approach is template subtraction:

•	Step 1 – Average all keypress-locked Baseline Block epochs to produce a clean motor ERP template (keypress-locked, no auditory component).
•	Step 2 – Convert the Action Main tone-locked epochs to keypress-locked by shifting the time axis by −250 ms (i.e. re-referencing time 0 to the keypress rather than the tone).
•	Step 3 – Subtract the motor template from the Action Main epochs. Both must be keypress-locked and perfectly aligned before subtraction.
•	Step 4 – Convert the cleaned epochs back to tone-locked by shifting the time axis +250 ms.
•	Step 5 – Apply baseline correction [−200 to 0 ms re tone] to both the motor-subtracted Action Main and the No-Action Main datasets identically.
•	Step 6 – Compute and compare N1 and P2 amplitudes between the clean Action Main and the No Action Main sets. Optionally compute a difference wave (Action − NoAction).

Something in this process is currently producing incorrect output. The task is to review the code, identify where the logic breaks down, and fix it.

Scripts Overview
•	PrepareData_6_ExtractConditions.m – Top-level wrapper. Auto-detects session type from event markers and calls the appropriate extraction function. Processes all post-ICA files for a subject.
•	extract_noaction_condition.m – Epochs all tone events (tone-locked), splits into Adaptation and Main blocks, saves raw (no baseline correction applied here).
•	extract_action_condition.m – Extracts keypress-locked Baseline epochs, tone-locked Adaptation epochs, and tone-locked Main epochs. All saved raw.
•	PrepareData_7_ComputeERPs.m – Top-level ERP wrapper. Calls motor subtraction, then computes N1/P2/P50 peaks per electrode group and per tone type, plots ERP waveforms and scalp topographies, saves per-subject Excel and .mat results.
•	subtract_motor_and_compute_difference.m – The core script that needs review. Builds the motor template, performs the time-axis shift, subtracts the template, re-locks to tone, applies baseline correction, and computes the difference wave.
•	compute_N1_P2.m – Computes P50, N1, and P2 peak and mean amplitudes per electrode group and per tone type for a given EEG dataset.
•	compare_N1_P2_amplitudes.m – Loads results for both conditions and blocks, generates bar plots, and runs basic statistical comparisons.
•	plot_grand_average_waveforms.m, plot_scalp_topographies.m, plot_action_noaction_comparison.m – Visualisation scripts.

What We Need
The pipeline runs without crashing but the motor subtraction output does not look right. We need an expert to:

•	Review the full subtraction logic in subtract_motor_and_compute_difference.m and identify where it goes wrong
•	Verify that the time-axis shift is handled correctly before and after subtraction
•	Check that the motor template and the action main epochs are aligned sample-for-sample before subtraction
•	Assess whether ERP-level subtraction (template subtracted from the average, not from individual trials) is the right approach here, or whether trial-level subtraction is more appropriate for this design
•	Ensure the final baseline correction [−200, 0 ms re tone] is applied identically and correctly to both the Action (motor-subtracted) and No-Action datasets
•	Fix any bugs found and test on at least one subject’s data
Files Provided
•	PrepareData_6_ExtractConditions.m – condition extraction
•	extract_action_condition.m / extract_noaction_condition.m – session-specific epoching
•	PrepareData_7_ComputeERPs.m – ERP computation wrapper
•	subtract_motor_and_compute_difference.m – the main file that needs review/fixing
•	compute_N1_P2.m, plot_*.m, compare_N1_P2_amplitudes.m – analysis and visualisation
•	Sample data from at least one subject (continuous + epoched .set files) can be shared via secure link

Deliverables
•	A corrected version of subtract_motor_and_compute_difference.m (and any other files that need changes)
•	A brief written explanation of what was wrong and what was changed
•	Example output figures from one subject showing the motor template, motor-subtracted Action ERP, No-Action ERP, and difference wave
•	Optional: a short code review document flagging any other issues in the pipeline


