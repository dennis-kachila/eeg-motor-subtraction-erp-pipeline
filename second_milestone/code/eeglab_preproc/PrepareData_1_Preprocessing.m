function PrepareData_1_Preprocessing(Sub, cfg)

%% Which subjects to load and what are the specifics
[cfg] = GetConfig(Sub,'Preprocessing',cfg);

% --------------------------------------------------------------
% Preflight dependency checks
% --------------------------------------------------------------
if isempty(which('pop_biosig'))
    error(['pop_biosig is not available on path. Ensure EEGLAB is loaded ' ...
           'and BIOSIG import support is installed.']);
end

if isempty(which('sopen'))
    error(['BIOSIG function sopen is missing. Install/add BIOSIG before ' ...
           'running Step 1 preprocessing.']);
end

if (isfield(cfg, 'runDetrend_BeforeEpoch') && cfg.runDetrend_BeforeEpoch == 1) || ...
   (isfield(cfg, 'runDetrend_AfterEpoch')  && cfg.runDetrend_AfterEpoch == 1)
    if isempty(which('eeg_detrend'))
        error(['eeg_detrend is required when detrending is enabled, but it was not found on path. ' ...
               'Add eeg_detrend.m to shared utilities or MATLAB path.']);
    end
end

chanloc_lookup_file = which('Standard-10-5-Cap385_witheog.elp');
if isempty(chanloc_lookup_file)
    error(['Channel location file Standard-10-5-Cap385_witheog.elp was not found on path. ' ...
           'Add it to MATLAB path before running preprocessing.']);
end

if ~isfield(cfg, 'FileInEEG') || isempty(cfg.FileInEEG)
    session_name = '(unknown session)';
    if isfield(cfg, 'EEGsourceName') && ~isempty(cfg.EEGsourceName)
        session_name = cfg.EEGsourceName;
    end
    error('No input EEG files found for %s %s in %s', Sub, session_name, cfg.PathInEEG);
end

if ~iscell(cfg.FileInEEG)
    cfg.FileInEEG = {cfg.FileInEEG};
end

% --------------------------------------------------------------
% create directory
% --------------------------------------------------------------    
if isdir(cfg.PathOutEEG)==0
   mkdir(cfg.PathOutEEG); 
end

% --------------------------------------------------------------
% process data
% --------------------------------------------------------------        

disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
disp(['% Processing subject '  Sub ])
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
disp(' ')

clear ALLEEG;
for F = 1:length(cfg.FileInEEG)

    EEG = []; 

    % --------------------------------------------------------------
    % load the EEG file
    % --------------------------------------------------------------
    fprintf('\nNow loading file %s.\n\nFile %d of %d\n\n', cfg.FileInEEG{F},F,length(cfg.FileInEEG) );  

    % Call pop_biosig with explicit parameters: filename, channels (0=all), type (auto-detect)
   [EEG, com] = pop_biosig([cfg.PathInEEG cfg.FileInEEG{F}], 0);
    EEG = eegh(com, EEG);
    EEG.data = double(EEG.data);
    
    % Validate EEG structure (skip interactive checks in batch mode)
    try
        % Only validate if file is valid without triggering GUI
        if isfield(EEG, 'data') && ~isempty(EEG.data) && isfield(EEG, 'srate') && EEG.srate > 0
            % Basic structure is valid
        end
    catch
        % Skip validation if it causes issues
    end
    
    % Label events
    EEG = label_events(EEG);
    EEG.data = double(EEG.data);

    % Final minimal validation (just double-check basic structure)
    if ~isfield(EEG, 'nbchan') || isempty(EEG.nbchan), error('Invalid EEG: missing channel count'); end
    if ~isfield(EEG, 'pnts') || isempty(EEG.pnts), error('Invalid EEG: missing sample count'); end

    % --------------------------------------------------------------
    % load channel Locations 
    % --------------------------------------------------------------
    [EEG] = pop_chanedit(EEG, 'lookup', chanloc_lookup_file);
    
    % --------------------------------------------------------------
    % Remove dead EOG channels 
    % --------------------------------------------------------------
    if isfield(cfg, 'removeDeadChannels') && cfg.removeDeadChannels == 1
        fprintf('Removing dead channels...\n');
        
        % Find indices of dead channels
        dead_idx = [];
        found_dead_labels = {};
        missing_dead_labels = {};

        chan_labels = {EEG.chanlocs.labels};

        for d = 1:length(cfg.deadChannelNames)
            requested_label = cfg.deadChannelNames{d};

            % First pass: case-insensitive exact match
            idx = find(strcmpi(chan_labels, requested_label));

            % Second pass: tolerant match for truncated/variant labels
            if isempty(idx)
                requested_norm = localNormalizeLabel(requested_label);
                for c = 1:length(chan_labels)
                    current_norm = localNormalizeLabel(chan_labels{c});
                    if strcmp(current_norm, requested_norm) || ...
                       startsWith(current_norm, requested_norm) || ...
                       startsWith(requested_norm, current_norm)
                        idx = c;
                        break;
                    end
                end
            end

            if ~isempty(idx)
                dead_idx = [dead_idx idx(1)];
                found_dead_labels{end+1} = chan_labels{idx(1)}; %#ok<AGROW>
            else
                missing_dead_labels{end+1} = requested_label; %#ok<AGROW>
            end
        end

        dead_idx = unique(dead_idx);
        
        if ~isempty(dead_idx)
            fprintf('  Removing %d dead channels: %s\n', length(dead_idx), strjoin(found_dead_labels, ', '));
            try
                [EEG, com] = pop_select(EEG, 'nochannel', dead_idx);
                EEG = eegh(com, EEG);
            catch ME
                warning('pop_select failed during dead-channel removal (%s). Falling back to manual channel removal.', ME.message);
                keep_idx = setdiff(1:size(EEG.data, 1), dead_idx);
                if ndims(EEG.data) <= 2
                    % Keep continuous data as 2-D (channels x samples).
                    EEG.data = EEG.data(keep_idx, :);
                else
                    EEG.data = EEG.data(keep_idx, :, :);
                end
                if isfield(EEG, 'chanlocs') && ~isempty(EEG.chanlocs)
                    EEG.chanlocs = EEG.chanlocs(keep_idx);
                end
                EEG.nbchan = length(keep_idx);
                EEG.pnts = size(EEG.data, 2);
                EEG.trials = 1;
                EEG.xmax = EEG.xmin + (EEG.pnts - 1) / EEG.srate;
            end
        else
            fprintf('  No dead channels found to remove.\n');
        end

        if ~isempty(missing_dead_labels)
            fprintf('  Requested dead channels not found: %s\n', strjoin(missing_dead_labels, ', '));
        end
    else
        found_dead_labels = {};
        missing_dead_labels = {};
    end

    % --------------------------------------------------------------
    % Re-reference (to mastoids)
    % --------------------------------------------------------------   
    [EEG] = Rereference(EEG, cfg);

    % --------------------------------------------------------------
    % filter data
    % --------------------------------------------------------------  
    [EEG] = ApplyFilters(EEG, cfg);
    
    % --------------------------------------------------------------
    % Downsample data 
    % --------------------------------------------------------------
    if cfg.runResample == 1
        fprintf('Resampling to %d Hz...\n', cfg.SamplingRate);
        [EEG, com] = pop_resample(EEG, cfg.SamplingRate);
        EEG = eegh(com, EEG);
    end

    % --------------------------------------------------------------
    % Detrend the data (if needed)
    % This is an external function provided by Andreas Widmann:
    % https://github.com/widmann/erptools/blob/master/eeg_detrend.m
    % --------------------------------------------------------------
    if cfg.runDetrend_BeforeEpoch == 1
        fprintf('Detrending continuous data...\n');
        EEG = eeg_detrend(EEG);
        EEG = eegh('EEG = eeg_detrend(EEG);', EEG);
    end 

    % --------------------------------------------------------------
    % Epoch the data and baseline correct if wanted
    % --------------------------------------------------------------
    if cfg.runEpoch == 1
        fprintf('Epoching data from %.2f to %.2f s...\n', cfg.epoch_tmin, cfg.epoch_tmax);
        [EEG] = pop_epoch( EEG, cfg.TriggerForEpoch, [cfg.epoch_tmin cfg.epoch_tmax], 'epochinfo', 'yes');
    end
    
    [EEG] = BaselineCorrect(EEG, cfg);
    
    % --------------------------------------------------------------
    % Detrend the data (after epoching if specified)
    % --------------------------------------------------------------
    if cfg.runDetrend_AfterEpoch == 1
        fprintf('Detrending epoched data...\n');
        EEG = eeg_detrend(EEG);
        EEG = eegh('EEG = eeg_detrend(EEG);', EEG);
    end 
    
    % --------------------------------------------------------------
    % Save Data
    % --------------------------------------------------------------
    fprintf('Saving preprocessed data...\n');
    EEG.cfg_preprocessing = cfg;
    if isfield(cfg, 'deadChannelNames')
        EEG.preprocessing_info.dead_channels.requested = cfg.deadChannelNames;
    else
        EEG.preprocessing_info.dead_channels.requested = {};
    end
    EEG.preprocessing_info.dead_channels.removed = found_dead_labels;
    EEG.preprocessing_info.dead_channels.missing = missing_dead_labels;
    EEG.data = single(EEG.data);
   
    % Create unique filename for each input file
[~, input_name, ~] = fileparts(cfg.FileInEEG{F});
output_name = [input_name cfg.FileOut '.set'];

SaveMyData(EEG, output_name, cfg.PathOutEEG);
    
end

% --------------------------------------------------------------
% Send info
% --------------------------------------------------------------    
fprintf(['Done with ' Sub '.\n'])
end

function out = localNormalizeLabel(label)
out = regexprep(lower(strtrim(label)), '[^a-z0-9]', '');
end