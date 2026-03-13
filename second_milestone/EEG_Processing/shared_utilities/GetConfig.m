function [cfg] = GetConfig(Sub, ScriptType, varargin)
% GetConfig - Build configuration for a specific subject, session, and pipeline step
%
% Called by each PrepareData_X function. Loads pipeline parameters and
% builds all file paths for the given subject and session.
%
% The session (EEGsourceName) is passed in via cfg from RunMyScripts,
% which discovers all BDF sessions per subject automatically.
% This means GetConfig never needs to guess which session to use.

%% Initialize paths
cfg = GetFilePathsAndInitializeToolboxes;

%% Get pipeline index
if nargin > 2
    cfg.Pipeline = varargin{1}.Pipeline;
else
    error('You need to provide pipeline index via cfg struct.');
end

cfg.Sub = Sub;
cfg.EEGsourceFiletype = '.bdf';

%% Get EEGsourceName (session identifier)
% Priority 1: explicitly passed in via cfg from RunMyScripts (preferred)
% Priority 2: auto-detect from sourcedata folder (fallback for manual calls)
if nargin > 2 && isfield(varargin{1}, 'EEGsourceName') && ~isempty(varargin{1}.EEGsourceName)

    cfg.EEGsourceName = varargin{1}.EEGsourceName;
    fprintf('Session: %s\n', cfg.EEGsourceName);

else
    % Fallback: find ALL BDF files and warn if multiple exist
    subject_eeg_folder = [cfg.PATH.SourcePath Sub filesep 'eeg' filesep];

    if exist(subject_eeg_folder, 'dir')
        bdf_files = dir(fullfile(subject_eeg_folder, [Sub '_ses-*_task-*_eeg.bdf']));

        if length(bdf_files) > 1
            warning(['Multiple sessions found for %s but none specified.\n' ...
                     'Defaulting to first: %s\n' ...
                     'Use RunMyScripts to process all sessions automatically.'], ...
                     Sub, bdf_files(1).name);
        end

        if ~isempty(bdf_files)
            tokens = regexp(bdf_files(1).name, ...
                [Sub '(_ses-\d+_task-[\w-]+_eeg)'], 'tokens');
            if ~isempty(tokens)
                cfg.EEGsourceName = tokens{1}{1};
                fprintf('Auto-detected session: %s\n', cfg.EEGsourceName);
            else
                cfg.EEGsourceName = '_ses-01_task-no-action_eeg';
                warning('Could not parse session from filename, using default.');
            end
        else
            cfg.EEGsourceName = '_ses-01_task-no-action_eeg';
            warning('No BDF files found for %s, using default session name.', Sub);
        end
    else
        cfg.EEGsourceName = '_ses-01_task-no-action_eeg';
        warning('Source folder not found for %s, using default session name.', Sub);
    end
end

%% Load pipeline configuration
myCFG = GetPipeline(cfg);

%% Merge pipeline parameters and build file paths
if ismember(ScriptType, fieldnames(myCFG))

    % Safely merge: add each pipeline field to cfg (handles overlapping fields)
    pipeline_params = myCFG.(ScriptType);
    param_fields = fieldnames(pipeline_params);
    for pf = 1:length(param_fields)
        cfg.(param_fields{pf}) = pipeline_params.(param_fields{pf});
    end

    switch ScriptType

        case 'Preprocessing'
            cfg.PathInEEG      = [cfg.PATH.SourcePath Sub filesep 'eeg' filesep];
            cfg.PathInBehavior = [cfg.PATH.SourcePath Sub filesep 'behavior' filesep];
            cfg.FileInEEG      = GetFileBySubstring(cfg.PathInEEG, cfg.EEGsourceFiletype);
            % Filter to only the BDF matching our session
            session_bdfs = cfg.FileInEEG(contains(cfg.FileInEEG, cfg.EEGsourceName));
            if ~isempty(session_bdfs)
                cfg.FileInEEG = session_bdfs;
            end
            cfg.FileOutEEG = [Sub cfg.EEGsourceName cfg.FileOut '.set'];
            cfg.PathOutEEG = [cfg.PATH.PreprocPath 'eeglab_preproc' filesep Sub filesep];

        case 'ExtractConditions'
            cfg = GetSubjectFileNamesForConditionExtraction(cfg, Sub);

        otherwise
            cfg = GetSubjectFileNames(cfg, Sub, cfg.FileIn, cfg.FileOut);
    end

else
    error('Method name "%s" not found in pipeline file.', ScriptType);
end

end


%% =========================================================
%% File path helpers
%% =========================================================
function [cfg] = GetSubjectFileNames(cfg, Sub, ReadName, WriteName)
% Map suffix names to derivative subfolders

    folder_map = struct(...
        'x_preproc',   'eeglab_preproc', ...
        'x_clean',     'eeglab_artifact_rejection', ...
        'x_ICA',       'eeglab_ICA', ...
        'x_ICrej',     'eeglab_IC_rejection', ...
        'x_post_ICA',  'eeglab_post_ICA', ...
        'x_final',     'eeglab_post_ICA');

    InputFolder  = getSuffix2Folder(ReadName,  folder_map);
    OutputFolder = getSuffix2Folder(WriteName, folder_map);

    if isempty(InputFolder)
        cfg.PathInEEG = [cfg.PATH.PreprocPath Sub filesep];
    else
        cfg.PathInEEG = [cfg.PATH.PreprocPath InputFolder filesep Sub filesep];
    end

    if isempty(OutputFolder)
        cfg.PathOutEEG = [cfg.PATH.PreprocPath Sub filesep];
    else
        cfg.PathOutEEG = [cfg.PATH.PreprocPath OutputFolder filesep Sub filesep];
    end

    cfg.FileInEEG  = [Sub cfg.EEGsourceName ReadName  '.set'];
    cfg.FileOutEEG = [Sub cfg.EEGsourceName WriteName '.set'];

end

function folder = getSuffix2Folder(suffix, folder_map)
    key = ['x' suffix];  % struct fields can't start with '_'
    key = strrep(key, '-', '_');  % sanitize hyphens
    if isfield(folder_map, key)
        folder = folder_map.(key);
    else
        folder = '';
    end
end

function [cfg] = GetSubjectFileNamesForConditionExtraction(cfg, Sub)

    cfg.PathInEEG = [cfg.PATH.PreprocPath 'eeglab_post_ICA' filesep Sub filesep];
    cfg.OUTPath   = [cfg.PATH.PreprocPath 'eeglab_epochs_per_block' filesep Sub filesep];

    % Look for the post-ICA file matching this session
    expected_file = [Sub cfg.EEGsourceName '_post_ICA.set'];

    if isfile([cfg.PathInEEG expected_file])
        cfg.FileInEEG = expected_file;
        fprintf('Found post-ICA file: %s\n', expected_file);
    else
        % List available files to help debugging
        available = dir([cfg.PathInEEG '*.set']);
        fprintf('Expected file not found: %s\n', expected_file);
        fprintf('Available files in %s:\n', cfg.PathInEEG);
        for i = 1:length(available)
            fprintf('  %s\n', available(i).name);
        end
        error('Post-ICA file not found for %s session %s', Sub, cfg.EEGsourceName);
    end

end

function myCFG = GetPipeline(cfg)

    myPipelineFolder = [cfg.PATH.PipelineAsset 'Pipeline_' sprintf('%03d', cfg.Pipeline) filesep];

    if ~exist(cfg.PATH.PipelineAsset, 'dir')
        error('Pipeline asset folder not found. Run CreateAndModifyPipelineAsset first.');
    end
    if ~exist(myPipelineFolder, 'dir')
        error('Pipeline %d does not exist. Run CreateAndModifyPipelineAsset(%d, 0) first.', ...
            cfg.Pipeline, cfg.Pipeline);
    end

    oldfiles = GetFileBySubstring(myPipelineFolder, 'version');
    if isempty(oldfiles)
        error('Pipeline folder exists but contains no version files.');
    end

    ID    = GetLastFileIndex(oldfiles);
    myCFG = load([myPipelineFolder 'Pipeline_' sprintf('%03d', cfg.Pipeline) ...
                  '_version' sprintf('%03d', ID) '.mat']);
    myCFG = myCFG.cfg;

end