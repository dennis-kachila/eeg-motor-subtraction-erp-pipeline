%% ========================================================================
%% RUN STEP 4: IC REJECTION FOR ALL SUBJECTS
%% ========================================================================
% This script runs Step 4 (ICLabel-based IC rejection) for all subjects
%
% ICA weights must already exist in derivatives/eeglab_ICA/ (Step 3)
% Output is saved to derivatives/eeglab_IC_rejection/
%
% Both task-action and task-no-action files will be processed automatically
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

% Pipeline index
pipeline = 1;

% Option 1: Process ALL subjects (leave empty)
subjects = [];

% Option 2: Process specific subjects (uncomment and modify as needed)
%subjects = {'sub-01'};
%subjects = {'sub-01', 'sub-02', 'sub-03', 'sub-04', 'sub-05', 'sub-06', ...
%            'sub-07', 'sub-08', 'sub-09', 'sub-10', 'sub-11', 'sub-12', 'sub-13'};

%% Run Step 4: IC Rejection
fprintf('=== RUNNING STEP 4: IC REJECTION ===\n');
fprintf('This will process both task-action and task-no-action files\n');
fprintf('Input:  derivatives/eeglab_ICA/\n');
fprintf('Output: derivatives/eeglab_IC_rejection/\n\n');

RunMyScripts('Subs', subjects, 'Script', 'PrepareData', 'Function', 4, 'Pipeline', pipeline);