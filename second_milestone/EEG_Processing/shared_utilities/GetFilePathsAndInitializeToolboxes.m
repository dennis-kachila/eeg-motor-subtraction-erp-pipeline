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
        % Add BIOSIG to path (selective: exclude legacy maybe-missing/freemat subdirs
        % that shadow MATLAB built-ins and cause issues with table loading)
        addpath(biosig_path);  % Main folder only
        
        % Add specific needed subfolders, excluding problematic legacy functions
        biosig_subfolds = {
            'eeglab'; ...          % EEGLAB integration
            't200_FileAccess'; ... % File I/O (contains sopen for BDF import)
            't210_Events'; ...     % Event handling
            't250_ArtifactPreProcessingQualityControl' ... % Artifact detection
        };
        
        for bf = 1:length(biosig_subfolds)
            subfold = fullfile(biosig_path, biosig_subfolds{bf});
            if exist(subfold, 'dir')
                addpath(subfold);
            end
        end
        
        fprintf('BIOSIG added to path (selective): %s\n', biosig_path);
    else
        fprintf('BIOSIG already on path.\n');
    end
else
    warning('BIOSIG folder not found. Tried: %s. Some functions may not work.', ...
        fullfile(BasePath, 'external', 'biosig', 'biosig4matlab'));
end