function cfgPath = GetFilePathsAndInitializeToolboxes
% Minimal local helper for this repository snapshot.
% Sets PreprocPath to repo root and adds EEGLAB if present under external/.

repoRoot = pwd;

% Add EEGLAB if it exists in the expected local folder.
eeglabRoot = fullfile(repoRoot, 'external', 'eeglab');
if exist(eeglabRoot, 'dir')
    addpath(genpath(eeglabRoot));
end

cfgPath = struct();
cfgPath.PATH = struct();
cfgPath.PATH.PreprocPath = [repoRoot filesep];
end
