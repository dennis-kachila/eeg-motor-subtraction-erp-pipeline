%% ========================================================================
%% RUN STEP 1 PREPROCESSING FOR ALL SUBJECTS
%% ========================================================================
% This script runs Step 1 (basic preprocessing) for all subjects
%
% This will process all subjects in your sourcedata folder
%% ========================================================================

clear all; close all; clc;

%% Initialize EEGLAB (if not already done)
eeglab nogui;


% Add shared utilities to path
% Linux legacy path (kept for reference)
% addpath('/data/projects/temporal_binding/code/shared_utilities');

% Windows/local path setup
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
%subjects = {'sub-10', 'sub-11', 'sub-12', 'sub-13'};

%% Check if pipeline exists, if not create it
cfg = GetFilePathsAndInitializeToolboxes;
pipeline_folder = [cfg.PATH.PipelineAsset 'Pipeline_' sprintf('%03d', pipeline) filesep];

if ~exist(pipeline_folder, 'dir')
    fprintf('Pipeline %d does not exist. Creating it now...\n', pipeline);
    CreateAndModifyPipelineAsset(pipeline, 0);
    fprintf('Pipeline %d created successfully.\n\n', pipeline);
else
    fprintf('Pipeline %d found. Proceeding with preprocessing...\n\n', pipeline);
end

%% Run Step 1: Preprocessing
fprintf('=== RUNNING STEP 1: PREPROCESSING ===\n');
fprintf('This will process both task-action and task-no-action files\n\n');

RunMyScripts('Subs', subjects, 'Script', 'PrepareData', 'Function', 1, 'Pipeline', pipeline);

fprintf('\n=== PREPROCESSING COMPLETE ===\n');
fprintf('Check the derivatives folder for preprocessed files.\n');
fprintf('Each subject should have both:\n');
fprintf('  - sub-XX_ses-01_task-no-action_eeg_preproc.set\n');
fprintf('  - sub-XX_ses-02_task-action_eeg_preproc.set\n');
