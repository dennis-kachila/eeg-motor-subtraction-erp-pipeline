%% Run Extract Conditions (Step 6)
% Epoch data and separate into adaptation and main blocks

clear all; close all; clc;

% OPTION 1: Process just sub-01
subjects = {'sub-01'};

% OPTION 2: Process ALL subjects (1-13)
% subjects = {'sub-01', 'sub-02', 'sub-03', 'sub-04', 'sub-05', 'sub-06', ...
%             'sub-07', 'sub-08', 'sub-09', 'sub-10', 'sub-11', 'sub-12', 'sub-13'};

fprintf('\n=== STARTING CONDITION EXTRACTION ===\n');
fprintf('Processing %d subjects\n\n', length(subjects));

cfg.Pipeline = 1;

for s = 1:length(subjects)
    Sub = subjects{s};
    fprintf('--- Processing %s (%d of %d) ---\n', Sub, s, length(subjects));
    try
        PrepareData_6_ExtractConditions(Sub, cfg);
    catch ME
        fprintf('\nERROR processing %s:\n', Sub);
        fprintf('%s\n', ME.message);
        fprintf('Continuing with next subject...\n\n');
    end
end

fprintf('\n=== CONDITION EXTRACTION COMPLETE ===\n');
fprintf('Results saved to eeglab_epochs_per_block/sub-XX/\n');