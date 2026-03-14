repoRoot = fileparts(mfilename('fullpath'));
projectRoot = repoRoot;

cd(projectRoot);

addpath(fullfile(projectRoot, 'EEG_Processing', 'shared_utilities'));
addpath(fullfile(projectRoot, 'EEG_Processing', 'eeglab_preproc'));
addpath(fullfile(projectRoot, 'EEG_Processing', 'eeglab_artifact_rejection'));
addpath(fullfile(projectRoot, 'EEG_Processing', 'eeglab_ICA'));
addpath(fullfile(projectRoot, 'EEG_Processing', 'eeglab_IC_rejection'));
addpath(fullfile(projectRoot, 'EEG_Processing', 'eeglab_post_ICA'));
addpath(fullfile(projectRoot, 'EEG_Processing', 'eeglab_epochs'));
addpath(fullfile(projectRoot, 'EEG_Processing', 'eeglab_ERP_analysis'));

% Initialize toolbox paths via shared utility to avoid BIOSIG genpath shadowing.
GetFilePathsAndInitializeToolboxes;
eeglab nogui;

subjects = {'sub-01'};
pipeline = 3;
cfg = struct('Pipeline', pipeline);

fprintf('\n========================================\n');
fprintf('SECOND MILESTONE BASELINE PIPELINE RUN\n');
fprintf('Project root: %s\n', projectRoot);
fprintf('Pipeline: %d\n', pipeline);
fprintf('Subjects: %s\n', strjoin(subjects, ', '));
fprintf('========================================\n\n');

cfgPath = GetFilePathsAndInitializeToolboxes;
pipelineFolder = fullfile(cfgPath.PATH.PipelineAsset, sprintf('Pipeline_%03d', pipeline));
if ~exist(pipelineFolder, 'dir')
    error('Pipeline folder not found at %s', pipelineFolder);
end

for step = 1:5
    fprintf('\n================ STEP %d ================\n', step);
    RunMyScripts('Subs', subjects, 'Script', 'PrepareData', ...
        'Function', sprintf('PrepareData_%d_%s', step, localStepName(step)), ...
        'Pipeline', pipeline, 'Sessions', {});
end

fprintf('\n================ STEP 6 ================\n');
RunMyScripts('Subs', subjects, 'Script', 'PrepareData', ...
    'Function', 'PrepareData_6_ExtractConditions', ...
    'Pipeline', pipeline, 'Sessions', {});

for subjectIndex = 1:numel(subjects)
    subjectId = subjects{subjectIndex};
    fprintf('\n================ STEP 7 ================\n');
    PrepareData_7_ComputeERPs(subjectId, cfg);
end

fprintf('\n========================================\n');
fprintf('BASELINE PIPELINE RUN COMPLETE\n');
fprintf('Outputs saved under %s\n', fullfile(projectRoot, 'derivatives'));
fprintf('========================================\n');

function stepName = localStepName(step)
switch step
    case 1
        stepName = 'Preprocessing';
    case 2
        stepName = 'AutomaticArtifactRejection';
    case 3
        stepName = 'RunICA';
    case 4
        stepName = 'RejectICs';
    case 5
        stepName = 'PostICAProcessing';
    otherwise
        error('Unsupported step: %d', step);
end
end