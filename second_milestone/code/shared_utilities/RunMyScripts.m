function RunMyScripts(varargin)

% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
% RunMyScripts - Main control function for EEG analysis pipeline
% $$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
%
% Loops over subject-session pairs so that subjects with multiple
% sessions (e.g. task-action AND task-no-action) are both processed.
%
% USAGE:
%   RunMyScripts('Subs', {'sub-01','sub-02'}, 'Script', 'PrepareData', ...
%                'Function', 1, 'Pipeline', 1)
%
%   RunMyScripts('Subs', [], ...)          % process ALL subjects
%
% OPTIONAL SESSION FILTER:
%   RunMyScripts(..., 'Sessions', {'ses-02_task-action'})
%   % Only process sessions whose name contains the given string(s).
%   % Default: process ALL sessions found for each subject.
%
% INPUTS:
%   'Subs'     - Cell array of subject IDs or [] for all
%   'Script'   - 'PrepareData' or 'Analysis'
%   'Function' - Step number (1-8) or function name string
%   'Pipeline' - Pipeline index (1-999)
%   'Sessions' - (optional) cell array of session filter strings

%% Initialize
cfg = GetFilePathsAndInitializeToolboxes;
clc;

%% Parse inputs
mySubs        = parseInput(varargin, 'mySubs');
myFunction    = parseInput(varargin, 'myFunction');
myPipeline    = parseInput(varargin, 'myPipeline');
sessionFilter = parseInput(varargin, 'sessionFilter');  % optional

%% Get subject list
if isempty(mySubs)
    subjects_dir = dir(cfg.PATH.SourcePath);
    subjects_dir = subjects_dir([subjects_dir.isdir]);
    mySubs = {subjects_dir(~ismember({subjects_dir.name}, {'.', '..'})).name};
    fprintf('Running for ALL subjects: %s\n', strjoin(mySubs, ', '));
else
    fprintf('Running for subjects: %s\n', strjoin(mySubs, ', '));
end

cfg.Pipeline = myPipeline;

fprintf('\n=======================================================\n');
fprintf('Running function: %s\n', myFunction);
fprintf('Pipeline: %d\n', myPipeline);
fprintf('=======================================================\n\n');

%% Loop over subjects AND sessions
total_processed = 0;
total_errors    = 0;

for s = 1:length(mySubs)

    Sub = mySubs{s};

    % ----------------------------------------------------------
    % Find all BDF sessions for this subject
    % ----------------------------------------------------------
    subject_eeg_folder = [cfg.PATH.SourcePath Sub filesep 'eeg' filesep];

    if ~exist(subject_eeg_folder, 'dir')
        fprintf('WARNING: No EEG folder found for %s at %s — skipping.\n', ...
            Sub, subject_eeg_folder);
        continue;
    end

    bdf_files = dir(fullfile(subject_eeg_folder, [Sub '_ses-*_task-*_eeg.bdf']));

    if isempty(bdf_files)
        fprintf('WARNING: No BDF files found for %s — skipping.\n', Sub);
        continue;
    end

    % ----------------------------------------------------------
    % Apply optional session filter
    % ----------------------------------------------------------
    if ~isempty(sessionFilter)
        keep = false(1, length(bdf_files));
        for f = 1:length(bdf_files)
            for sf = 1:length(sessionFilter)
                if contains(bdf_files(f).name, sessionFilter{sf})
                    keep(f) = true;
                end
            end
        end
        bdf_files = bdf_files(keep);
        if isempty(bdf_files)
            fprintf('WARNING: No sessions matching filter for %s — skipping.\n', Sub);
            continue;
        end
    end

    fprintf('\n--- Subject %s (%d of %d): %d session(s) found ---\n', ...
        Sub, s, length(mySubs), length(bdf_files));

    % ----------------------------------------------------------
    % Loop over sessions
    % ----------------------------------------------------------
    for f = 1:length(bdf_files)

        % Parse session name from BDF filename
        tokens = regexp(bdf_files(f).name, ...
            [Sub '(_ses-\d+_task-[\w-]+_eeg)'], 'tokens');

        if isempty(tokens)
            fprintf('  WARNING: Cannot parse session name from %s — skipping.\n', ...
                bdf_files(f).name);
            continue;
        end

        EEGsourceName = tokens{1}{1};  % e.g. '_ses-01_task-no-action_eeg'

        fprintf('\n  Session %d of %d: %s\n', f, length(bdf_files), EEGsourceName);

        % Pass session explicitly via cfg
        session_cfg          = cfg;
        session_cfg.Pipeline = myPipeline;
        session_cfg.EEGsourceName = EEGsourceName;

        try
            feval(myFunction, Sub, session_cfg);
            total_processed = total_processed + 1;

        catch ME
            total_errors = total_errors + 1;
            fprintf('\n  ERROR processing %s %s:\n', Sub, EEGsourceName);
            fprintf('  %s\n', ME.message);
            fprintf('  Stack trace:\n');
            for k = 1:length(ME.stack)
                fprintf('    File: %s  |  Line: %d\n', ...
                    ME.stack(k).file, ME.stack(k).line);
            end
            fprintf('  Continuing with next session...\n\n');
        end

    end  % sessions loop

end  % subjects loop

fprintf('\n=======================================================\n');
fprintf('Pipeline complete.\n');
fprintf('  Sessions processed successfully: %d\n', total_processed);
fprintf('  Sessions with errors:            %d\n', total_errors);
fprintf('=======================================================\n');

end


%% =========================================================
%% Input parsing helpers
%% =========================================================
function myOut = parseInput(inputArgs, type)

    switch type

        case 'myFunction'
            Index = FindStringInCell(inputArgs, 'Function');
            if isempty(Index)
                error('You forgot to provide the "Function" argument.');
            end
            myVarargin = inputArgs{Index+1};

            if ischar(myVarargin) || isstring(myVarargin)
                myVarargin = char(myVarargin);
                func_location = which(myVarargin);
                if ~isempty(func_location)
                    myOut = strrep(myVarargin, '.m', '');
                else
                    error('Function "%s" not found on MATLAB path.', myVarargin);
                end

            elseif isnumeric(myVarargin) && length(myVarargin) == 1
                scriptIdx = FindStringInCell(inputArgs, 'Script');
                if isempty(scriptIdx)
                    error('Script type not specified. Use ''PrepareData'' or ''Analysis''.');
                end
                scriptType = inputArgs{scriptIdx+1};

                if contains(scriptType, 'PrepareData', 'IgnoreCase', true)
                    % Search across ALL step-specific folders on the path
                    % because each PrepareData script lives in a different folder
                    step_folders = {
                        'eeglab_preproc', 'eeglab_artifact_rejection', ...
                        'eeglab_ICA', 'eeglab_IC_rejection', ...
                        'eeglab_post_ICA', 'eeglab_epochs', ...
                        'eeglab_ERP_analysis'
                    };

                    % Get base project path from GetFilePathsAndInitializeToolboxes
                    base_cfg  = GetFilePathsAndInitializeToolboxes;
            
                    % Use CodePath directly (either EEG_Processing or legacy code folder)
                    code_path = base_cfg.PATH.CodePath;
                    
                    myFiles = {};
                    for sf = 1:length(step_folders)
                        folder = [code_path step_folders{sf} filesep];
                        if exist(folder, 'dir')
                            found = GetFileBySubstring(folder, 'PrepareData_');
                            % Prefix with folder so we can call which() later
                            for ff = 1:length(found)
                                myFiles{end+1} = found{ff};
                            end
                        end
                    end

                    if isempty(myFiles)
                        error('No PrepareData functions found across step folders.');
                    end

                elseif contains(scriptType, 'Analysis', 'IgnoreCase', true)
                    myFiles = GetFileBySubstring(cd, 'MyAnalysis_');
                else
                    error('Script type must be "PrepareData" or "Analysis".');
                end

                mySearchString = ['_' num2str(myVarargin) '_'];
                idx  = contains(myFiles, mySearchString, 'IgnoreCase', true);
                idx2 = contains(myFiles, '.m', 'IgnoreCase', true);

                if sum(idx & idx2) == 1
                    myOut = strrep(myFiles{idx & idx2}, '.m', '');
                elseif sum(idx & idx2) == 0
                    error('Function number %d not found. Available: %s', ...
                        myVarargin, strjoin(myFiles, ', '));
                else
                    error('Multiple functions match number %d.', myVarargin);
                end
            else
                error('Function input must be a string or integer.');
            end

        case 'myPipeline'
            Index = FindStringInCell(inputArgs, 'Pipeline');
            if isempty(Index)
                error('You forgot to provide the "Pipeline" argument.');
            end
            myVarargin = inputArgs{Index+1};
            if isnumeric(myVarargin) && length(myVarargin) == 1
                myOut = myVarargin;
                if myOut < 1 || myOut > 999
                    error('Pipeline index must be between 1 and 999.');
                end
            else
                error('"Pipeline" must be a single number.');
            end

        case 'mySubs'
            Index = FindStringInCell(inputArgs, 'Subs');
            if isempty(Index)
                error('You forgot to provide the "Subs" argument.');
            end
            myVarargin = inputArgs{Index+1};
            if iscell(myVarargin)
                myOut = myVarargin;
            elseif isempty(myVarargin)
                myOut = [];
            else
                error('"Subs" must be a cell array or [].');
            end

        case 'sessionFilter'
            Index = FindStringInCell(inputArgs, 'Sessions');
            if isempty(Index)
                myOut = {};  % no filter = process all sessions
            else
                myVarargin = inputArgs{Index+1};
                if iscell(myVarargin)
                    myOut = myVarargin;
                elseif ischar(myVarargin)
                    myOut = {myVarargin};
                else
                    error('"Sessions" must be a cell array of strings.');
                end
            end

        otherwise
            error('Unknown input type: %s', type);
    end

end