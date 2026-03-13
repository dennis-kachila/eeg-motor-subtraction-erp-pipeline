%% ========================================================================
%% RUN STEP 3: ICA FOR ALL SUBJECTS
%% ========================================================================
% This script runs Step 3 (ICA decomposition) for all subjects
%
% Cleaned data must already exist in derivatives/eeglab_artifact_rejection/ (Step 2)
% Output is saved to derivatives/eeglab_ICA/
%
% WARNING: ICA is slow - expect long runtime depending on data length
%% ========================================================================

clear all; close all; clc;

%% Initialize EEGLAB (if not already done)
eeglab nogui;

%% Add shared utilities to path
% Legacy Linux path (kept for reference):
% addpath('/data/projects/temporal_binding/code/shared_utilities');

% Windows/local path setup - resolve shared_utilities relative to this script
this_script_dir = fileparts(mfilename('fullpath'));
code_root = fileparts(this_script_dir);

shared_utils_candidates = {
    fullfile(code_root, 'shared_utilities'), ...
    fullfile(fileparts(code_root), 'EEG_Processing', 'shared_utilities')
};

for p = 1:numel(shared_utils_candidates)
    if exist(shared_utils_candidates{p}, 'dir')
        addpath(shared_utils_candidates{p});
    end
end

%% Define subjects to process

% Option 1: Process ALL subjects (leave empty)
subjects = [];

% Option 2: Process specific subjects (uncomment and modify as needed)
%subjects = {'sub-01'};
%subjects = {'sub-01', 'sub-02', 'sub-03', 'sub-04', 'sub-05', 'sub-06', ...
%            'sub-07', 'sub-08', 'sub-09', 'sub-10', 'sub-11', 'sub-12', 'sub-13'};

% Pipeline index
pipeline = 1;

%% Run ICA
fprintf('=== RUNNING STEP 3: ICA ===\n');
fprintf('This will process both task-action and task-no-action files\n');
fprintf('Input:  derivatives/eeglab_artifact_rejection/\n');
fprintf('Output: derivatives/eeglab_ICA/\n\n');

RunMyScripts('Subs', subjects, 'Script', 'PrepareData', 'Function', 3, 'Pipeline', pipeline);