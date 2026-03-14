function cfg = GetFilePathsAndInitializeToolboxes

%% Where to find EEG data and everything else

% get current working directory
Path = cd;
cfg.PATH.AnalysisPath = [Path filesep];

% Assume standard folder structure (current milestone layout):
% project/
%   ├── sourcedata/
%   ├── derivatives/
%   └── EEG_Processing/  (where scripts are)
%       ├── eeglab_preproc/
%       ├── shared_utilities/
%       └── Pipelines/
%
% Legacy support is also kept for:
% project/code/

% Try to find the base project folder
if contains(Path, 'EEG_Processing')
    % We're somewhere in EEG_Processing folder (e.g., EEG_Processing/eeglab_preproc/)
    % Go up to the EEG_Processing parent (project root)
    parts = strsplit(Path, filesep);
    eeg_proc_idx = find(strcmp(parts, 'EEG_Processing'), 1, 'first');
    if ~isempty(eeg_proc_idx)
        % Reconstruct path up to (but not including) 'EEG_Processing'
        % Include drive letter on Windows (parts{1} is 'C:')
        if length(parts) >= eeg_proc_idx
            BasePath = fullfile(parts{1:eeg_proc_idx-1});
        else
            BasePath = Path;
        end
    else
        % Fallback - assume current is base
        BasePath = Path;
    end
elseif contains(Path, 'code')
    % Legacy: We're somewhere in code folder (e.g., code/eeglab_preproc/)
    % Go up to project root
    parts = strsplit(Path, filesep);
    code_idx = find(strcmp(parts, 'code'), 1, 'first');
    if ~isempty(code_idx)
        % Reconstruct path up to (but not including) 'code'
        % Include drive letter on Windows (parts{1} is 'C:')
        if length(parts) >= code_idx
            BasePath = fullfile(parts{1:code_idx-1});
        else
            BasePath = Path;
        end
    else
        % Fallback - assume current is base
        BasePath = Path;
    end
elseif contains(Path, 'analysis')
    % Old naming - analysis folder, go up one level
    cd('..');
    BasePath = cd;
    cd(cfg.PATH.AnalysisPath);
else
    % assume current folder is the base
    BasePath = Path;
end

% Set up paths
% Support both 'code' (legacy) and 'EEG_Processing' (milestone) structures
if exist([BasePath filesep 'EEG_Processing'], 'dir')
    % Use EEG_Processing structure
    cfg.PATH.CodePath = [BasePath filesep 'EEG_Processing' filesep];
    cfg.PATH.PipelineAsset = [BasePath filesep 'EEG_Processing' filesep 'Pipelines' filesep];
elseif exist([BasePath filesep 'code'], 'dir')
    % Use legacy code structure
    cfg.PATH.CodePath = [BasePath filesep 'code' filesep];
    cfg.PATH.PipelineAsset = [BasePath filesep 'code' filesep 'Pipelines' filesep];
else
    % Default to EEG_Processing if neither exists yet
    cfg.PATH.CodePath = [BasePath filesep 'EEG_Processing' filesep];
    cfg.PATH.PipelineAsset = [BasePath filesep 'EEG_Processing' filesep 'Pipelines' filesep];
end

cfg.PATH.SourcePath = [BasePath filesep 'sourcedata' filesep];
cfg.PATH.PreprocPath = [BasePath filesep 'derivatives' filesep];

% Remove stale project-related path entries (common after folder moves).
cleanup_stale_project_paths();

% Create directories if they don't exist
if ~exist(cfg.PATH.SourcePath, 'dir')
    fprintf('Warning: sourcedata folder not found. Creating it at:\n%s\n', cfg.PATH.SourcePath);
    mkdir(cfg.PATH.SourcePath);
end

if ~exist(cfg.PATH.PreprocPath, 'dir')
    fprintf('Creating derivatives folder at:\n%s\n', cfg.PATH.PreprocPath);
    mkdir(cfg.PATH.PreprocPath);
end

if ~exist(cfg.PATH.PipelineAsset, 'dir')
    fprintf('Creating Pipelines folder at:\n%s\n', cfg.PATH.PipelineAsset);
    mkdir(cfg.PATH.PipelineAsset);
end

%% Check for EEGLAB

% Add EEGLAB root path if needed (do not add all subfolders).
eeglab_candidates = {
    fullfile(BasePath, 'external', 'eeglab');
    fullfile(BasePath, '..', 'external', 'eeglab')
};
if isempty(which('eeglab'))
    for ec = 1:numel(eeglab_candidates)
        if exist(eeglab_candidates{ec}, 'dir')
            addpath(eeglab_candidates{ec});
            break;
        end
    end
end

% Check if EEGLAB is already on the path
if exist('eeglab.m', 'file')
    fprintf('EEGLAB found on path.\n');
else
    % Try to find EEGLAB
    warning('EEGLAB not found on path. Please add EEGLAB to your MATLAB path.');
    fprintf('You can do this by running:\n');
    fprintf('  addpath(''path/to/eeglab'');\n');
    fprintf('  eeglab nogui;\n\n');
end

%% Check for and add BIOSIG to path

% BIOSIG can be at root level (parent of second_milestone) or in a code/EEG_Processing folder
biosig_path = fullfile(BasePath, 'external', 'biosig', 'biosig4matlab');

% If not found at root, try one level up (for second_milestone layout)
if ~exist(biosig_path, 'dir')
    biosig_path = fullfile(BasePath, '..', 'external', 'biosig', 'biosig4matlab');
end

if exist(biosig_path, 'dir')
    if isempty(which('sopen'))
        % Add only the BIOSIG subfolders needed for BDF loading.
        % Using selective subfolders avoids shadowing MATLAB/EEGLAB built-ins
        % present in other BIOSIG trees (e.g. filter.m, classify.m, bandpower.m).
        % biosig2eeglab.m has been patched to sanitize InChanSelect (handles
        % 0-indexed values returned by sopen when partial BIOSIG is loaded).
        biosig_subfolders = {'t200_FileAccess', 't210_Events', 't250_ArtifactPreProcessingQualityControl'};
        for k = 1:numel(biosig_subfolders)
            sf = fullfile(biosig_path, biosig_subfolders{k});
            if exist(sf, 'dir')
                addpath(sf);
            end
        end
        fprintf('BIOSIG added to path (selective subfolders for BDF loading): %s\n', biosig_path);
    else
        fprintf('BIOSIG already on path.\n');
    end
else
    warning('BIOSIG folder not found. Tried: %s. Some functions may not work.', ...
        fullfile(BasePath, 'external', 'biosig', 'biosig4matlab'));
end

end


function cleanup_stale_project_paths()
% Remove invalid path entries tied to this repository and EEGLAB .git internals.
repo_tag = 'eeg-motor-subtraction-erp-pipeline';

all_paths = strsplit(path, pathsep);
for i = 1:numel(all_paths)
    this_path = all_paths{i};
    if isempty(this_path)
        continue;
    end

    in_repo_scope = contains(this_path, repo_tag, 'IgnoreCase', true);
    is_eeglab_git_path = contains(this_path, [filesep 'external' filesep 'eeglab' filesep '.git'], 'IgnoreCase', true);

    remove_path = false;
    if in_repo_scope && exist(this_path, 'dir') ~= 7
        remove_path = true;
    end
    if is_eeglab_git_path
        remove_path = true;
    end

    if remove_path
        try
            rmpath(this_path);
        catch
            % Continue cleanup even if one path cannot be removed.
        end
    end
end
end