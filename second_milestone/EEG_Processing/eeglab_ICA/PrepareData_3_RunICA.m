function PrepareData_3_RunICA(Sub, cfg)

%% Instruction
%
% Run this over night as it might take a while
% ICA will be run on cleaned, continuous data
%
% This script processes BOTH task-action and task-no-action files
% regardless of session number.

%% Which subjects to load and what are the specifics
[cfg] = GetConfig(Sub,'RunICA', cfg);

% Find all cleaned files for this subject (regardless of session)
input_path = [cfg.PATH.PreprocPath 'eeglab_artifact_rejection' filesep Sub filesep];
output_path = [cfg.PATH.PreprocPath 'eeglab_ICA' filesep Sub filesep];

% Create output directory if it doesn't exist
if ~exist(output_path, 'dir')
    mkdir(output_path);
end

% Determine which files to process
% If EEGsourceName is specified (from RunMyScripts), process only that session
% Otherwise, fall back to scanning all files (for backward compatibility)
if isfield(cfg, 'EEGsourceName') && ~isempty(cfg.EEGsourceName)
    % Session-specific dispatch from RunMyScripts
    input_file = [Sub cfg.EEGsourceName '_clean.set'];
    if exist([input_path input_file], 'file')
        all_files = struct('name', {input_file});
    else
        fprintf('Warning: Expected file not found for %s session %s\n', Sub, cfg.EEGsourceName);
        return;
    end
else
    % Backward compatibility: scan all .set files for this subject
    all_files = dir([input_path '*.set']);
    
    if isempty(all_files)
        fprintf('Warning: No cleaned files found for %s\n', Sub);
        return;
    end
end

% Initialize EEGLAB once
eeglab nogui;

% Process each file found
for f = 1:length(all_files)
    
    input_file = all_files(f).name;
    
    % Skip if not a task file (must contain 'task-action' or 'task-no-action')
    if ~contains(input_file, 'task-action') && ~contains(input_file, 'task-no-action')
        continue;
    end
    
    fprintf('\n========================================\n');
    fprintf('=== Processing %s ===\n', input_file);
    fprintf('========================================\n\n');
    
    % Build output filename (keep same naming as input, just change suffix)
    output_file = strrep(input_file, '_clean.set', '_ICA.set');
    
    % --------------------------------------------------------------
    % load the EEG file
    % --------------------------------------------------------------
    fprintf('Loading cleaned data: %s...\n', input_file);
    [EEG, com] = pop_loadset(input_file, input_path);
    EEG = eegh(com, EEG);
    EEG.data = double(EEG.data);
    
    [EEG, com] = eeg_checkset( EEG );
    EEG = eegh(com, EEG);
    
    % --------------------------------------------------------------
    % Re-Reference and Baseline correct before ICA
    % --------------------------------------------------------------   
    [EEG] = Rereference(EEG, cfg);
    [EEG] = BaselineCorrect(EEG, cfg);
    
    % --------------------------------------------------------------
    % Determine which channels to use for ICA
    % --------------------------------------------------------------
    % by default, use all scalp channels (exclude EOG, mastoids, etc)
    ica_chans = cfg.ica_chans;
    if isempty(ica_chans)
        % get indices of EEG channels only
        eeg_chans = find(strcmp({EEG.chanlocs.type}, 'EEG'));
        if isempty(eeg_chans)
            % if type is not set, use all channels
            ica_chans = 1:EEG.nbchan;
        else
            ica_chans = eeg_chans;
        end
        fprintf('Using %d scalp channels for ICA.\n', length(ica_chans));
    end
    
    % --------------------------------------------------------------
    % Determine number of components to extract
    % --------------------------------------------------------------
    % Check rank of data (can be reduced if channels were interpolated)
    data_rank = rank(double(EEG.data(:,:)'));
    
    ica_ncomps = cfg.ica_ncomps;
    if isempty(ica_ncomps)
        ica_ncomps = data_rank;
        fprintf('Data rank is %d. Extracting %d ICA components.\n', data_rank, ica_ncomps);
    else
        if ica_ncomps > data_rank
            warning('Requested %d components but data rank is only %d. Using %d components.', ...
                ica_ncomps, data_rank, data_rank);
            ica_ncomps = data_rank;
        end
        fprintf('Extracting %d ICA components from %d channels.\n', ...
            ica_ncomps, length(ica_chans));
    end
    
    % --------------------------------------------------------------
    % Run ICA
    % --------------------------------------------------------------        
    fprintf('Running ICA (this may take a while)...\n');
    tic;
    
    [EEG,com] = eeg_checkset(EEG);
    EEG = eegh(com, EEG);

    % Resolve ICA backend with speed-aware fallback.
    requested_ica_type = cfg.ica_type;
    if strcmpi(requested_ica_type, 'auto_fast')
        has_picard = ~isempty(which('picard')) || ~isempty(which('eegplugin_picard'));
        has_binica = ~isempty(which('binica'));
        if has_picard
            ica_type_to_use = 'picard';
        elseif has_binica
            ica_type_to_use = 'binica';
        else
            ica_type_to_use = 'runica';
        end
        fprintf('ICA backend auto-selected: %s\n', ica_type_to_use);
    else
        ica_type_to_use = requested_ica_type;
    end
    
    % Run ICA with specified parameters
    try
        EEG = pop_runica(EEG, 'icatype', ica_type_to_use, ...
                       'extended', cfg.ica_extended, ...
                       'chanind', ica_chans, ...
                       'pca', ica_ncomps);
    catch ME
        if ~strcmpi(ica_type_to_use, 'runica')
            warning('ICA backend %s failed (%s). Falling back to runica.', ...
                ica_type_to_use, ME.message);
            ica_type_to_use = 'runica';
            EEG = pop_runica(EEG, 'icatype', ica_type_to_use, ...
                           'extended', cfg.ica_extended, ...
                           'chanind', ica_chans, ...
                           'pca', ica_ncomps);
        else
            rethrow(ME);
        end
    end
    
    elapsed_time = toc;
    fprintf('ICA completed in %.1f minutes using %s.\n', elapsed_time/60, ica_type_to_use);
    
    % --------------------------------------------------------------
    % Save Data
    % --------------------------------------------------------------    
    fprintf('Saving ICA results to: %s\n', output_path);
    EEG.cfg_ICcalculation = cfg;
    EEG.ica_info.input_file = input_file;
    EEG.ica_info.n_components = ica_ncomps;
    EEG.ica_info.channels_used = ica_chans;
    EEG.ica_info.ica_type_requested = requested_ica_type;
    EEG.ica_info.ica_type_used = ica_type_to_use;
    EEG.data = single(EEG.data);
    SaveMyData(EEG, output_file, output_path);
    
    fprintf('Done with %s\n\n', input_file);
    
end

% --------------------------------------------------------------
% Send Info
% --------------------------------------------------------------   
fprintf('========================================\n');
fprintf('Completed ICA for %s\n', Sub);
fprintf('========================================\n\n');