%% ========================================================================
%% STEP 6 - EXTRACT CONDITIONS
%% ========================================================================
%
% Calls:   extract_noaction_condition.m, extract_action_condition.m
% Input:   derivatives/eeglab_post_ICA/sub-XX/
% Output:  derivatives/eeglab_epochs_per_block/sub-XX/
%
% Takes the cleaned continuous EEG and cuts it into epochs. The script auto-detects
% whether it is processing the No-Action or Action session based on the
% event markers in the file.
%
% ------------------------------------------------------------------------
% HOW TO RUN
% ------------------------------------------------------------------------
%
%   % Single subject
%   RunMyScripts('Subs', {'sub-01'}, 'Script', 'PrepareData', 'Function', 6, 'Pipeline', 1)
%
%   % All subjects
%   RunMyScripts('Subs', {'sub-01','sub-02','sub-03'}, 'Script', 'PrepareData', 'Function', 6, 'Pipeline', 1)
%
% ------------------------------------------------------------------------
% EPOCH PARAMETERS
% ------------------------------------------------------------------------
%
%   Window              : -449 ms to +645 ms relative to time-locking event
%   Baseline correction : -448 ms to -250 ms (pre-stimulus)
%   Tone events         : Tone_Low, Tone_Med, Tone_High
%   Keypress events     : Key_Press
%   Adaptation block (No Action)    : First 100 epochs
%   Main block (No Action)         : Epochs 101 onward
%
% ------------------------------------------------------------------------
% NO-ACTION SESSION
% ------------------------------------------------------------------------
%
% The participant listened passively. The script epochs
% the continuous recording around every tone event, applies baseline
% correction, and splits into adaptation and main blocks.
%
% Output files:
%
%   sub-XX_ses-01_task-no-action_eeg_all.set
%       All tone epochs combined. e.g, sub-01: 618 epochs.
%
%   sub-XX_ses-01_task-no-action_eeg_adaptation.set
%       First 100 tones. Used to characterise the habituation response,
%       not included in the main Action vs No-Action comparison.
%       e.g, sub-01: 100 epochs.
%
%   sub-XX_ses-01_task-no-action_eeg_main.set
%       All tones after the first 100. This is the primary No-Action
%       dataset used for ERP analysis and comparison with Action.
%       Baseline corrected. e.g, sub-01: 518 epochs.
%
% ------------------------------------------------------------------------
% ACTION SESSION
% ------------------------------------------------------------------------
%
% The participant pressed a key 250 ms before each tone.
% This means every tone epoch contains motor-related brain activity that
% overlaps with the N1 and P2 components we want to measure. The script
% therefore produces two separate types of epoched data.
%
% --------------------------------------------------------------
% TONE-LOCKED EPOCHS (adaptation and main blocks)
% --------------------------------------------------------------
%
% Created the same way as the No-Action session — time 0 is the tone.
%
% The main block is saved WITHOUT baseline correction. This is intentional.
% Baseline correction must happen after motor subtraction (Step 7), not
% before — applying it here would distort the motor signal we need to
% remove cleanly.
%
% Output files:
%
%   sub-XX_ses-02_task-action_eeg_all_action.set
%       All tone epochs combined. e.g., sub-01: 636 epochs.
%
%   sub-XX_ses-02_task-action_eeg_adaptation_action.set
%       First 100 tones. Baseline corrected. e.g, sub-01: 100 epochs.
%
%   sub-XX_ses-02_task-action_eeg_main_action.set
%       All tones after the first 100. Tone-locked. NO baseline
%       correction — intentional, see note above. This is the dataset
%       that goes into motor subtraction in Step 7.
%       e.g, sub-01: 536 epochs.
%
% --------------------------------------------------------------
% KEYPRESS-LOCKED EPOCHS (motor template)
% --------------------------------------------------------------
%
% The experiment starts with a Baseline Block where the participant
% presses keys at will with no tones playing. The script isolates this
% period and epochs around every Key_Press event. Time 0 is the keypress.
%
% These epochs contain only motor brain activity with no auditory
% response. They serve as the motor template that is subtracted from the
% action main epochs in Step 7 to recover the clean auditory ERP.
%
% Output file:
%
%   sub-XX_ses-02_task-action_eeg_baseline_action.set
%       Pure motor keypresses from the baseline block. Keypress-locked.
%       No baseline correction. e.g., sub-01: 59 epochs.
%