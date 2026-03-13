%% Run Compute ERPs (Step 7)
% Calculate N1 and P2 amplitudes and latencies
%
% Uncomment the subjects line you want to use

clear all; close all; clc;

% Ensure shared utilities are available when launching this script directly.
this_script_dir = fileparts(mfilename('fullpath'));
if isempty(this_script_dir)
    this_script_dir = pwd;
end
code_root = fileparts(this_script_dir);
shared_utils_dir = fullfile(code_root, 'shared_utilities');

if exist(shared_utils_dir, 'dir')
    addpath(shared_utils_dir);
else
    error('Shared utilities folder not found: %s', shared_utils_dir);
end

% Keep local Step 7 helpers resolvable if MATLAB was launched elsewhere.
addpath(this_script_dir);

% OPTION 1: Process just sub-01
subjects = {'sub-01'};


% OPTION 2: Process ALL subjects (1-13)
% subjects = {'sub-01', 'sub-02', 'sub-03', 'sub-04', 'sub-05', 'sub-06', ...
%             'sub-07', 'sub-08', 'sub-09', 'sub-10', 'sub-11', 'sub-12', 'sub-13'};

% Setup
fprintf('\n=== STARTING ERP COMPUTATION ===\n');
fprintf('Processing %d subjects\n\n', length(subjects));

% Create config with pipeline info
cfg.Pipeline = 1;

% Process each subject
for s = 1:length(subjects)
    Sub = subjects{s};
    
    fprintf('--- Processing %s (%d of %d) ---\n', Sub, s, length(subjects));
    
    try
        % Call the function directly
        PrepareData_7_ComputeERPs(Sub, cfg);
        
    catch ME
        fprintf('\nERROR processing %s:\n', Sub);
        fprintf('%s\n', ME.message);
        fprintf('Continuing with next subject...\n\n');
    end
end

fprintf('\n=== ERP COMPUTATION COMPLETE ===\n');
fprintf('Results saved to eeglab_ERPs/sub-XX/\n');