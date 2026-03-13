function cfgPath = GetFilePathsAndInitializeToolboxes
% Workspace bootstrap helper.
% Supports launching from repository root as well as second_milestone subfolders.

repoRoot = pwd;

% If currently inside second_milestone, use that as base; otherwise use
% repository root and look for second_milestone children.
if contains(repoRoot, [filesep 'second_milestone'])
    parts = strsplit(repoRoot, filesep);
    idx = find(strcmp(parts, 'second_milestone'), 1, 'first');
    if ~isempty(idx)
        basePath = fullfile(parts{1:idx});
    else
        basePath = repoRoot;
    end
else
    if exist(fullfile(repoRoot, 'second_milestone'), 'dir')
        basePath = fullfile(repoRoot, 'second_milestone');
    else
        basePath = repoRoot;
    end
end

% Add EEGLAB if it exists in expected local folders.
eeglabCandidates = {
    fullfile(repoRoot, 'external', 'eeglab'), ...
    fullfile(basePath, 'external', 'eeglab'), ...
    fullfile(basePath, '..', 'external', 'eeglab')
};

for i = 1:numel(eeglabCandidates)
    eeglabRoot = eeglabCandidates{i};
    if exist(eeglabRoot, 'dir')
        addpath(genpath(eeglabRoot));
        break;
    end
end

cfgPath = struct();
cfgPath.PATH = struct();
cfgPath.PATH.AnalysisPath = [repoRoot filesep];

if exist(fullfile(basePath, 'EEG_Processing'), 'dir')
    cfgPath.PATH.CodePath = [fullfile(basePath, 'EEG_Processing') filesep];
    cfgPath.PATH.PipelineAsset = [fullfile(basePath, 'EEG_Processing', 'Pipelines') filesep];
elseif exist(fullfile(basePath, 'code'), 'dir')
    cfgPath.PATH.CodePath = [fullfile(basePath, 'code') filesep];
    cfgPath.PATH.PipelineAsset = [fullfile(basePath, 'code', 'Pipelines') filesep];
else
    cfgPath.PATH.CodePath = [fullfile(basePath, 'EEG_Processing') filesep];
    cfgPath.PATH.PipelineAsset = [fullfile(basePath, 'EEG_Processing', 'Pipelines') filesep];
end

cfgPath.PATH.SourcePath = [fullfile(basePath, 'sourcedata') filesep];
cfgPath.PATH.PreprocPath = [fullfile(basePath, 'derivatives') filesep];

if ~exist(cfgPath.PATH.SourcePath, 'dir')
    mkdir(cfgPath.PATH.SourcePath);
end
if ~exist(cfgPath.PATH.PreprocPath, 'dir')
    mkdir(cfgPath.PATH.PreprocPath);
end
if ~exist(cfgPath.PATH.PipelineAsset, 'dir')
    mkdir(cfgPath.PATH.PipelineAsset);
end
end
