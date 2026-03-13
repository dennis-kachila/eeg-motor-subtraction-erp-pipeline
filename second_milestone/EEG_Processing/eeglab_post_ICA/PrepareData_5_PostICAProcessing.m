function PrepareData_5_PostICAProcessing(Sub, cfg)

%% Instructions
% This function performs post-ICA processing:
% 1. Additional epoch rejection based on amplitude thresholds (if data is epoched)
% 2. Interpolation of bad channels that were removed earlier
% 3. Final re-referencing (e.g., to mastoids)
%
% This function is called per session by RunMyScripts.

%% Which subjects to load and what are the specifics
[cfg] = GetConfig(Sub,'PostICA', cfg);

% Use session-resolved paths from GetConfig (single file per call)
input_path = cfg.PathInEEG;
output_path = cfg.PathOutEEG;
input_file = cfg.FileInEEG;
output_file = cfg.FileOutEEG;

% Create output directory if it doesn't exist
if ~exist(output_path, 'dir')
    mkdir(output_path);
end

% Validate expected single-session input
if ~isfile([input_path input_file])
    fprintf('Warning: IC-rejected file not found for %s session %s\n', Sub, cfg.EEGsourceName);
    fprintf('Expected: %s\n', [input_path input_file]);
    return;
end

% Initialize EEGLAB once
eeglab nogui;

fprintf('\n========================================\n');
fprintf('=== Processing %s ===\n', input_file);
fprintf('========================================\n\n');
    
% --------------------------------------------------------------
% load the EEG file
% --------------------------------------------------------------
fprintf('Loading IC-rejected data: %s...\n', input_file);
[EEG, com] = pop_loadset(input_file, input_path);
EEG = eegh(com, EEG);
EEG.data = double(EEG.data);

[EEG, com] = eeg_checkset(EEG);
EEG = eegh(com, EEG);

% --------------------------------------------------------------
% Interpolate bad channels if needed
% --------------------------------------------------------------
if cfg.interpolate_channels == 1
    if isfield(EEG, 'artifact_rejection_info') && ...
       isfield(EEG.artifact_rejection_info, 'removed_channels') && ...
       ~isempty(EEG.artifact_rejection_info.removed_channels)

        removed_channels = EEG.artifact_rejection_info.removed_channels;

        % Filter out EOG channels - only interpolate EEG channels
        eog_patterns = {'EOG', 'VEOG', 'HEOG', 'Vertical', 'Horizontal', 'Up ', 'Down '};

        % Find which removed channels are EEG (not EOG)
        eeg_channels_to_interpolate = {};
        for i = 1:length(removed_channels)
            chan_name = removed_channels{i};
            is_eog = false;
            for p = 1:length(eog_patterns)
                if contains(chan_name, eog_patterns{p}, 'IgnoreCase', true)
                    is_eog = true;
                    break;
                end
            end
            if ~is_eog
                eeg_channels_to_interpolate{end+1} = chan_name;
            end
        end
            
        if ~isempty(eeg_channels_to_interpolate)
            fprintf('Interpolating %d EEG channels (excluding EOG)...\n', length(eeg_channels_to_interpolate));
            fprintf('Channels to interpolate: %s\n', strjoin(eeg_channels_to_interpolate, ', '));
            
            % Get original channel locations
            if isfield(EEG.artifact_rejection_info, 'original_chanlocs')
                original_chanlocs = EEG.artifact_rejection_info.original_chanlocs;
            else
                % Reconstruct original chanlocs by loading standard locations
                fprintf('Reconstructing original channel locations...\n');
                
                % Create a temporary EEG structure with all original channels
                EEG_temp = EEG;
                
                % Add back the removed channels as empty data
                for i = 1:length(removed_channels)
                    EEG_temp.chanlocs(end+1).labels = removed_channels{i};
                end
                
                % Look up standard locations
                [EEG_temp, ~] = pop_chanedit(EEG_temp, 'lookup','Standard-10-5-Cap385_witheog.elp');
                original_chanlocs = EEG_temp.chanlocs;
                clear EEG_temp;
            end
            
            % Find channel structures for the channels to interpolate
            chans_to_interp_struct = [];
            for i = 1:length(eeg_channels_to_interpolate)
                idx = find(strcmp({original_chanlocs.labels}, eeg_channels_to_interpolate{i}));
                if ~isempty(idx)
                    chans_to_interp_struct = [chans_to_interp_struct original_chanlocs(idx(1))];
                end
            end
            
            if ~isempty(chans_to_interp_struct)
                % Interpolate channels
                try
                    [EEG, com] = pop_interp(EEG, chans_to_interp_struct, 'spherical');
                    EEG = eegh(com, EEG);
                    fprintf('Channel interpolation complete.\n');
                catch ME
                    fprintf('Warning: Interpolation failed with error: %s\n', ME.message);
                    fprintf('Continuing without interpolation.\n');
                end
            else
                fprintf('Warning: Could not find channel locations for interpolation.\n');
            end
        else
            fprintf('No EEG channels to interpolate (only EOG channels were removed).\n');
        end
        
        if length(eeg_channels_to_interpolate) < length(removed_channels)
            skipped = setdiff(removed_channels, eeg_channels_to_interpolate);
            fprintf('Skipped interpolating EOG channels: %s\n', strjoin(skipped, ', '));
        end
    else
        fprintf('No bad channels to interpolate.\n');
    end
end

% --------------------------------------------------------------
% Additional epoch rejection based on amplitude
% --------------------------------------------------------------
if cfg.runEpochRejection == 1 && ndims(EEG.data) == 3

    fprintf('\nPerforming epoch rejection...\n');
    n_epochs_before = EEG.trials;

    % Reject based on amplitude threshold
    [EEG, com] = pop_eegthresh(EEG, 1, 1:EEG.nbchan, ...
        -cfg.voltage_threshold, cfg.voltage_threshold, ...
        EEG.xmin, EEG.xmax, 0, 0);
    EEG = eegh(com, EEG);

    % Reject based on joint probability if requested
    if cfg.use_probability == 1
        [EEG, com] = pop_jointprob(EEG, 1, 1:EEG.nbchan, ...
            cfg.probability_threshold, cfg.probability_threshold, 0, 0);
        EEG = eegh(com, EEG);
    end

    % Actually reject the marked epochs
    if any(EEG.reject.rejthresh) || any(EEG.reject.rejjp)
        [EEG, com] = pop_rejepoch(EEG, [EEG.reject.rejthresh | EEG.reject.rejjp], 0);
        EEG = eegh(com, EEG);
    end

    n_epochs_after = EEG.trials;
    n_epochs_rejected = n_epochs_before - n_epochs_after;

    fprintf('Epochs rejected: %d of %d (%.1f%%)\n', ...
        n_epochs_rejected, n_epochs_before, 100*n_epochs_rejected/n_epochs_before);

    % Store rejection info
    EEG.epoch_rejection_info.n_epochs_before = n_epochs_before;
    EEG.epoch_rejection_info.n_epochs_after = n_epochs_after;
    EEG.epoch_rejection_info.n_epochs_rejected = n_epochs_rejected;
else
    fprintf('Skipping epoch rejection (continuous data or not requested).\n');
end

% --------------------------------------------------------------
% Final re-reference
% --------------------------------------------------------------
reference_mode = 'not_applied';
reference_channels_used = {};

if cfg.runReref == 1
    if ~isempty(cfg.Reference{1})
        requested_ref = cfg.Reference;
        requested_ref_lower = lower(strtrim(requested_ref));
        chan_labels = lower(strtrim({EEG.chanlocs.labels}));
        available_ref_mask = ismember(requested_ref_lower, chan_labels);
        available_ref = requested_ref(available_ref_mask);

        if isempty(available_ref)
            fprintf('Requested reference channels unavailable. Applying average-reference fallback.\n');
            [EEG, com] = pop_reref(EEG, [], 'keepref', 'on');
            EEG = eegh(com, EEG);
            reference_mode = 'average_fallback';
        else
            [EEG] = Rereference(EEG, cfg);
            reference_mode = 'requested_reference';
            reference_channels_used = available_ref;
            fprintf('Final re-reference complete using available channels: %s\n', strjoin(lower(strtrim(available_ref)), ', '));
        end
    else
        [EEG] = Rereference(EEG, cfg);
        reference_mode = 'average_requested';
        fprintf('Final re-reference complete using average reference (configured).\n');
    end
end

% --------------------------------------------------------------
% Save Data
% --------------------------------------------------------------
fprintf('Saving final preprocessed data to: %s\n', output_path);
EEG.cfg_postica = cfg;
EEG.postica_reference_info.mode = reference_mode;
EEG.postica_reference_info.channels_used = reference_channels_used;
EEG.data = single(EEG.data);
SaveMyData(EEG, output_file, output_path);

fprintf('Done with %s\n\n', input_file);
fprintf('Final data: %d channels, continuous\n', EEG.nbchan);

% --------------------------------------------------------------
% Send info
% --------------------------------------------------------------    
fprintf('========================================\n');
fprintf('Completed post-ICA processing for %s\n', Sub);
fprintf('========================================\n\n');