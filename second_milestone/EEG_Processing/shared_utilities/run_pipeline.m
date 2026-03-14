%% ========================================================================
%% TEMPORAL BINDING EEG PIPELINE - UNIFIED RUNNER
%% ========================================================================
% Replaces all individual run_preproc.m, run_artifact_rejection.m, etc.
%
% HOW TO USE:
%   1. Set 'subjects' (or leave [] for all)
%   2. Set 'steps' to whichever steps you want to run
%   3. Optionally set 'session_filter' to process only one task
%   4. Run the script
%
% SESSIONS are auto-discovered per subject from sourcedata/.
% Both ses-01_task-no-action and ses-02_task-action will be processed
% unless you filter with 'session_filter'.
%
% PIPELINE STEPS:
%   1 - Preprocessing (rereference, filter, then downsample)
%   2 - Automated artifact rejection (pop_clean_rawdata)
%   3 - ICA decomposition  [slow - run overnight]
%   4 - IC rejection (ICLabel)
%   5 - Post-ICA processing (final rereference)
%   6 - Extract conditions (epoch into adaptation/main blocks)
%   7 - Compute ERPs (N1/P2)
%   8 - Create summary table
%% ========================================================================

clear all; close all; clc;

%% Add paths
this_script_dir = fileparts(mfilename('fullpath'));
if isempty(this_script_dir)
    this_script_dir = pwd;
end
code_root = fileparts(this_script_dir);

step_dirs = {
    'shared_utilities', ...
    'eeglab_preproc', ...
    'eeglab_artifact_rejection', ...
    'eeglab_ICA', ...
    'eeglab_IC_rejection', ...
    'eeglab_post_ICA', ...
    'eeglab_epochs', ...
    'eeglab_ERP_analysis'
};

for d = 1:numel(step_dirs)
    full_dir = fullfile(code_root, step_dirs{d});
    if exist(full_dir, 'dir')
        addpath(full_dir);
    else
        warning('run_pipeline:MissingPath', 'Path not found: %s', full_dir);
    end
end

eeglab nogui;

%% -----------------------------------------------------------------------
%% CONFIGURE HERE
%% -----------------------------------------------------------------------

% Subjects to process ([] = all subjects in sourcedata/)
subjects = {'sub-01'};

% Steps to run (e.g. [1 2] runs Steps 1 and 2 only)
steps = [6];

% Pipeline index
pipeline = 3;

% Session filter (optional):
%   []                       = process ALL sessions per subject
%   {'task-no-action'}       = only no-action sessions
%   {'task-action'}          = only action sessions
%   {'task-no-action', 'task-action'} = both (same as [])
session_filter = {'task-action'};   % <-- change as needed

%% -----------------------------------------------------------------------
%% RUN PIPELINE
%% -----------------------------------------------------------------------

cfg = GetFilePathsAndInitializeToolboxes;

% Check pipeline exists
pipeline_folder = [cfg.PATH.PipelineAsset 'Pipeline_' sprintf('%03d', pipeline) filesep];
if ~exist(pipeline_folder, 'dir')
    fprintf('Pipeline %d not found. Creating it now...\n', pipeline);
    CreateAndModifyPipelineAsset(pipeline, 0);
end

for step = steps

    fprintf('\n========================================================\n');
    fprintf('  STEP %d\n', step);
    fprintf('========================================================\n');

    if step < 8
        RunMyScripts('Subs',     subjects, ...
                     'Script',   'PrepareData', ...
                     'Function', step, ...
                     'Pipeline', pipeline, ...
                     'Sessions', session_filter);
    else
        % Step 8 aggregates all subjects — run once, not per-session
        fprintf('\n=== STEP 8: CREATE SUMMARY TABLE ===\n');
        cfg.Pipeline = pipeline;
        PrepareData_8_CreateSummaryTable(cfg);
    end

end

fprintf('\n========================================================\n');
fprintf('  PIPELINE COMPLETE\n');
fprintf('========================================================\n');