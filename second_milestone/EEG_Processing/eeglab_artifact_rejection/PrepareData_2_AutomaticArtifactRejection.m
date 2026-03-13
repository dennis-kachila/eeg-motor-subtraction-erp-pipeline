function PrepareData_2_AutomaticArtifactRejection(Sub, cfg)
%% Instructions
% This function performs automated artifact rejection using pop_clean_rawdata
% from the clean_rawdata plugin (part of EEGLAB).
%
% IMPORTANT: Singleton block markers (Baseline_Block, Adaptation_Block, etc.)
% are preserved before cleaning and re-injected afterward, because
% pop_clean_rawdata removes any event that falls in a rejected time segment.

%% Get config
[cfg] = GetConfig(Sub, 'AutoReject', cfg);

% --------------------------------------------------------------
% Load the EEG file
% --------------------------------------------------------------
fprintf('Loading preprocessed data for %s...\n', Sub);
[EEG, com] = pop_loadset(cfg.FileInEEG, cfg.PathInEEG);
EEG = eegh(com, EEG);
EEG.data = double(EEG.data);

[EEG, com] = eeg_checkset(EEG);
EEG = eegh(com, EEG);

% --------------------------------------------------------------
% Re-reference and baseline correct
% --------------------------------------------------------------
[EEG] = Rereference(EEG, cfg);
[EEG] = BaselineCorrect(EEG, cfg);

% --------------------------------------------------------------
% Store original channel information
% --------------------------------------------------------------
original_nbchan   = EEG.nbchan;
original_chanlocs = EEG.chanlocs;
n_samples_before  = EEG.pnts;

% --------------------------------------------------------------
% Preserve singleton block markers before artifact rejection
% Store only type and latency - avoid struct field compatibility issues
% --------------------------------------------------------------
block_marker_types = {'Baseline_Block', 'Adaptation_Block', 'Practice_Block', ...
                      'Main_Block', 'Experiment_Start', 'Experiment_End', ...
                      'BASELINE_START', 'ADAPTATION_START', 'PRACTICE_START', ...
                      'MAIN_START', 'EXPERIMENT_START', 'EXPERIMENT_END'};

preserved_types     = {};
preserved_latencies = [];

fprintf('Preserving critical block markers...\n');
for i = 1:length(EEG.event)
    if ismember(EEG.event(i).type, block_marker_types)
        preserved_types{end+1}     = EEG.event(i).type;
        preserved_latencies(end+1) = EEG.event(i).latency;
        fprintf('  Preserved: %s at latency %.1f\n', EEG.event(i).type, EEG.event(i).latency);
    end
end

% --------------------------------------------------------------
% Run automated artifact rejection
% --------------------------------------------------------------
% Preflight: ensure clean_rawdata plugin is available
if isempty(which('pop_clean_rawdata'))
    error('PrepareData_2:MissingPlugin', ...
        'pop_clean_rawdata not found. Install the clean_rawdata EEGLAB plugin.');
end

fprintf('Running automated artifact rejection...\n');
fprintf('Parameters:\n');
fprintf('  Flatline criterion: %d seconds\n', cfg.FlatlineCriterion);
fprintf('  Channel criterion: %.2f\n', cfg.ChannelCriterion);
fprintf('  Line noise criterion: %d SD\n', cfg.LineNoiseCriterion);
fprintf('  Burst criterion: %d\n', cfg.BurstCriterion);
fprintf('  Window criterion: %.2f\n', cfg.WindowCriterion);

EEG = pop_clean_rawdata(EEG, ...
    'FlatlineCriterion', cfg.FlatlineCriterion, ...
    'ChannelCriterion',  cfg.ChannelCriterion, ...
    'LineNoiseCriterion',cfg.LineNoiseCriterion, ...
    'BurstCriterion',    cfg.BurstCriterion, ...
    'WindowCriterion',   cfg.WindowCriterion, ...
    'BurstRejection',    cfg.BurstRejection, ...
    'Distance',          cfg.Distance);

[EEG, com] = eeg_checkset(EEG);
EEG = eegh(com, EEG);

n_samples_after = EEG.pnts;

% --------------------------------------------------------------
% Re-inject preserved block markers
% We copy an existing event and overwrite type/latency to ensure
% full field compatibility with EEG.event struct array
% --------------------------------------------------------------
fprintf('Restoring critical block markers...\n');

for i = 1:length(preserved_types)

    marker_type = preserved_types{i};
    orig_lat    = preserved_latencies(i);

    % Check if marker survived artifact rejection
    already_present = ~isempty(EEG.event) && any(strcmp({EEG.event.type}, marker_type));

    if ~already_present
        % Map original sample index to post-cleaning index using the
        % sample mask stored by pop_clean_rawdata. This is exact:
        % clean_sample_mask(i)==true means original sample i was kept.
        if isfield(EEG, 'etc') && isfield(EEG.etc, 'clean_sample_mask')
            mask = EEG.etc.clean_sample_mask;
            orig_idx = min(round(orig_lat), length(mask));
            if mask(orig_idx)
                scaled_lat = sum(mask(1:orig_idx));
            else
                % Marker fell in a rejected window - find nearest kept sample
                later = find(mask(orig_idx:end), 1, 'first');
                if ~isempty(later)
                    scaled_lat = sum(mask(1:orig_idx + later - 2)) + 1;
                else
                    earlier = find(mask(1:orig_idx), 1, 'last');
                    scaled_lat = ~isempty(earlier) * sum(mask(1:earlier));
                    scaled_lat = max(scaled_lat, 1);
                end
            end
        else
            % Fallback: proportional scaling (less accurate)
            scaled_lat = round((orig_lat / n_samples_before) * n_samples_after);
        end
        scaled_lat = max(1, min(scaled_lat, n_samples_after));

        % Build a new event with correct field structure
        if ~isempty(EEG.event)
            new_event = EEG.event(1);
        else
            % No events survived - build a minimal template
            new_event.type     = '';
            new_event.latency  = 1;
            new_event.duration = 0;
            new_event.urevent  = [];
            new_event.channel  = 0;
        end
        new_event.type    = marker_type;
        new_event.latency = scaled_lat;
        if isfield(new_event, 'duration'), new_event.duration = 0; end
        if isfield(new_event, 'urevent'),  new_event.urevent  = []; end
        if isfield(new_event, 'channel'),  new_event.channel  = 0;  end

        EEG.event(end+1) = new_event;

        fprintf('  Restored: %s at sample %d (%.1f s)\n', ...
            marker_type, scaled_lat, scaled_lat/EEG.srate);
    else
        fprintf('  %s: survived artifact rejection\n', marker_type);
    end
end

% Re-sort events by latency and check consistency
if ~isempty(EEG.event)
    [~, sort_idx] = sort([EEG.event.latency]);
    EEG.event = EEG.event(sort_idx);
end
EEG = eeg_checkset(EEG, 'eventconsistency');

% --------------------------------------------------------------
% Report
% --------------------------------------------------------------
removed_channels   = setdiff({original_chanlocs.labels}, {EEG.chanlocs.labels});
n_removed_channels = length(removed_channels);

fprintf('\n=== Artifact Rejection Summary ===\n');
fprintf('Samples: %d -> %d (kept %.1f%%)\n', ...
    n_samples_before, n_samples_after, 100*n_samples_after/n_samples_before);
fprintf('Channels removed: %d of %d\n', n_removed_channels, original_nbchan);
if n_removed_channels > 0
    fprintf('Removed channels: %s\n', strjoin(removed_channels, ', '));
end

fprintf('\nFinal event types:\n');
final_types = unique({EEG.event.type});
for i = 1:length(final_types)
    n = sum(strcmp({EEG.event.type}, final_types{i}));
    fprintf('  %-25s: %d\n', final_types{i}, n);
end

% --------------------------------------------------------------
% Save rejection info
% --------------------------------------------------------------
EEG.artifact_rejection_info.removed_channels   = removed_channels;
EEG.artifact_rejection_info.n_removed_channels = n_removed_channels;
EEG.artifact_rejection_info.original_nbchan    = original_nbchan;
EEG.artifact_rejection_info.original_chanlocs  = original_chanlocs;
EEG.artifact_rejection_info.n_samples_before   = n_samples_before;
EEG.artifact_rejection_info.n_samples_after    = n_samples_after;

% --------------------------------------------------------------
% Save Data
% --------------------------------------------------------------
fprintf('Saving cleaned data...\n');
EEG.cfg_autoreject = cfg;
EEG.data = single(EEG.data);
SaveMyData(EEG, cfg.FileOutEEG, cfg.PathOutEEG);

fprintf(['Done with ' Sub '.\n']);