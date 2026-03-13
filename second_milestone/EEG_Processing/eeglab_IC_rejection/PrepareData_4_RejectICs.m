function PrepareData_4_RejectICs(Sub, cfg)

%% Instruction
%
% This function uses ICLabel to automatically classify and reject
% independent components that represent artifacts (eye movements, muscle,
% heart, line noise, channel noise).
%
% Components are rejected if they have >90% probability of being an artifact
% type AND <30% probability of being brain activity.
%
% This function is called per session by RunMyScripts.

%% Which subjects to load and what are the specifics
[cfg] = GetConfig(Sub,'RejICA', cfg);

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
    fprintf('Warning: ICA file not found for %s session %s\n', Sub, cfg.EEGsourceName);
    fprintf('Expected: %s\n', [input_path input_file]);
    return;
end

% Initialize EEGLAB once
eeglab nogui;

% Preflight dependency check
if cfg.use_iclabel && isempty(which('pop_iclabel'))
    error('PrepareData_4:MissingPlugin', ...
        'pop_iclabel not found. Install the ICLabel EEGLAB plugin.');
end
    
fprintf('\n========================================\n');
fprintf('=== Processing %s ===\n', input_file);
fprintf('========================================\n\n');
    
% --------------------------------------------------------------
% load the EEG file
% --------------------------------------------------------------
fprintf('Loading ICA results: %s...\n', input_file);
[EEG, com] = pop_loadset('filename', input_file, 'filepath', input_path, 'check', 'off');
EEG = eegh(com, EEG);
EEG.data = double(EEG.data);

% Some legacy ICA files carry inconsistent icachansind length metadata.
% Normalize this before any eeg_checkset/ICLabel call to avoid GUI prompts.
EEG = normalize_icachansind_metadata(EEG);
    
[EEG, com] = eeg_checkset( EEG );
EEG = eegh(com, EEG);
    
% Check if ICA was run
if isempty(EEG.icaweights)
    error('No ICA decomposition found. Run PrepareData_3_RunICA first.');
end
    
% --------------------------------------------------------------
% Run ICLabel classification
% --------------------------------------------------------------
if cfg.use_iclabel
    fprintf('Running ICLabel classification...\n');
    n_components = size(EEG.icaweights, 1);
    try
        EEG = pop_iclabel(EEG, 'default');
    catch ME_iclabel
        fprintf('ICLabel failed on native montage (%s). Trying channel-consistent fallback...\n', ME_iclabel.message);

        EEG_fallback = build_iclabel_fallback_dataset(EEG);

        try
            EEG_fallback = pop_iclabel(EEG_fallback, 'default');
            EEG.etc.ic_classification = EEG_fallback.etc.ic_classification;
            fprintf('ICLabel fallback succeeded.\n');
        catch ME_iclabel_fallback
            warning('PrepareData_4:ICLabelFailed', ...
                'ICLabel failed after fallback: %s. Keeping all components.', ME_iclabel_fallback.message);
            classifications = zeros(n_components, 7);
            classifications(:, 1) = 1; % brain=100%% fallback to avoid accidental rejection
            EEG.etc.ic_classification.ICLabel.classifications = classifications;
            EEG.etc.ic_classification.ICLabel.classes = ...
                {'brain','muscle','eye','heart','line noise','channel noise','other'};
            EEG.etc.ic_classification.ICLabel.fallback_error = ME_iclabel_fallback.message;
        end
    end
else
    error('PrepareData_4:ConfigUnsupported', 'cfg.use_iclabel=0 is not supported in this workflow.');
end
    
    % --------------------------------------------------------------
    % Identify components to reject based on ICLabel classifications
    % --------------------------------------------------------------
    % ICLabel categories: [Brain, Muscle, Eye, Heart, Line Noise, Channel Noise, Other]
    
classifications = EEG.etc.ic_classification.ICLabel.classifications;
n_components = size(classifications, 1);
    
% Initialize rejection array
reject_ic = zeros(1, n_components);
    
for ic = 1:n_components
    % Get probabilities for each category
    prob_brain = classifications(ic, 1);
    prob_muscle = classifications(ic, 2);
    prob_eye = classifications(ic, 3);
    prob_heart = classifications(ic, 4);
    prob_line_noise = classifications(ic, 5);
    prob_channel_noise = classifications(ic, 6);
        
    % Reject if high probability of artifact AND low probability of brain
    if prob_brain < cfg.brain_threshold
        
        % Check each artifact type based on configuration
        if (cfg.reject_muscle && prob_muscle > cfg.artifact_threshold) || ...
           (cfg.reject_eye && prob_eye > cfg.artifact_threshold) || ...
           (cfg.reject_heart && prob_heart > cfg.artifact_threshold) || ...
           (cfg.reject_line_noise && prob_line_noise > cfg.artifact_threshold) || ...
           (cfg.reject_channel_noise && prob_channel_noise > cfg.artifact_threshold)
            
            reject_ic(ic) = 1;
        end
    end
end
    
% Convert to indices
reject_idx = find(reject_ic);
    
% --------------------------------------------------------------
% Report what will be rejected
% --------------------------------------------------------------
fprintf('\n=== IC Rejection Summary ===\n');
fprintf('Total components: %d\n', n_components);
fprintf('Components to reject: %d (%.1f%%)\n', length(reject_idx), 100*length(reject_idx)/n_components);
    
if ~isempty(reject_idx)
    fprintf('\nRejected components by type:\n');
    for ic = reject_idx
        [~, max_idx] = max(classifications(ic, :));
        category_names = {'Brain', 'Muscle', 'Eye', 'Heart', 'Line Noise', 'Channel Noise', 'Other'};
        fprintf('  IC %d: %s (%.1f%% probability)\n', ic, category_names{max_idx}, ...
            100*classifications(ic, max_idx));
    end
end
    
% --------------------------------------------------------------
% Mark components for rejection
% --------------------------------------------------------------
EEG.reject.gcompreject = reject_ic;
    
% --------------------------------------------------------------
% Remove rejected ICA components
% --------------------------------------------------------------
if ~isempty(reject_idx)
    fprintf('\nRemoving %d artifact components...\n', length(reject_idx));
    [EEG, com] = pop_subcomp(EEG, reject_idx, 0);
    EEG = eegh(com, EEG);
else
    fprintf('\nNo components rejected (all components appear to be brain activity).\n');
end
    
% --------------------------------------------------------------
% Save rejection info
% --------------------------------------------------------------
EEG.ic_rejection_info.rejected_components = reject_idx;
EEG.ic_rejection_info.n_rejected = length(reject_idx);
EEG.ic_rejection_info.classifications = classifications;
EEG.ic_rejection_info.rejection_criteria.brain_threshold = cfg.brain_threshold;
EEG.ic_rejection_info.rejection_criteria.artifact_threshold = cfg.artifact_threshold;
EEG.ic_rejection_info.input_file = input_file;
            
% --------------------------------------------------------------
% Save Data
% --------------------------------------------------------------    
fprintf('Saving IC-rejected data to: %s\n', output_path);
EEG.cfg_rejica = cfg;
EEG.data = single(EEG.data);
SaveMyData(EEG, output_file, output_path);

fprintf('Done with %s\n\n', input_file);

% --------------------------------------------------------------
% Send Info
% --------------------------------------------------------------   
fprintf('========================================\n');
fprintf('Completed IC rejection for %s\n', Sub);
fprintf('========================================\n\n');

function EEG_fallback = build_iclabel_fallback_dataset(EEG)
EEG_fallback = EEG;

scalp_idx = get_scalp_channel_indices(EEG);
if isempty(scalp_idx)
    return;
end

% Keep only channels that are both scalp-like and part of the ICA model.
if isfield(EEG, 'icachansind') && ~isempty(EEG.icachansind)
    ica_chan_idx = EEG.icachansind(:)';
else
    ica_chan_idx = 1:EEG.nbchan;
end

selected_orig_idx = ica_chan_idx(ismember(ica_chan_idx, scalp_idx));
if isempty(selected_orig_idx)
    return;
end

EEG_fallback.data = EEG.data(selected_orig_idx, :, :);
EEG_fallback.nbchan = numel(selected_orig_idx);
EEG_fallback.chanlocs = EEG.chanlocs(selected_orig_idx);
EEG_fallback.icachansind = 1:EEG_fallback.nbchan;

% Clear inherited ICA fields before chanloc lookup to avoid transient
% dimension mismatch checks inside EEGLAB utilities.
EEG_fallback.icaweights = [];
EEG_fallback.icasphere = [];
EEG_fallback.icawinv = [];
EEG_fallback.icaact = [];

for chan_idx = 1:numel(EEG_fallback.chanlocs)
    EEG_fallback.chanlocs(chan_idx).type = 'EEG';
end

lookup_file = which('Standard-10-5-Cap385_witheog.elp');
if ~isempty(lookup_file)
    try
        EEG_fallback = pop_chanedit(EEG_fallback, 'lookup', lookup_file);
    catch ME_lookup
        warning('PrepareData_4:LookupFailed', ...
            'Standard channel lookup failed during ICLabel fallback: %s', ME_lookup.message);
    end
end

if isfield(EEG, 'icaweights') && ~isempty(EEG.icaweights) && ...
   isfield(EEG, 'icasphere') && ~isempty(EEG.icasphere)
    % Rebuild a consistent ICA factorization for selected channels:
    % W_full = icaweights * icasphere (nComp x nICAch)
    % W_sel  = W_full(:, selected_channels)
    W_full = EEG.icaweights * EEG.icasphere;

    [is_kept, kept_positions] = ismember(selected_orig_idx, ica_chan_idx);
    kept_positions = kept_positions(is_kept);

    if ~isempty(kept_positions)
        W_sel = W_full(:, kept_positions);
        EEG_fallback.icaweights = W_sel;
        EEG_fallback.icasphere = eye(size(W_sel, 2));
        EEG_fallback.icawinv = pinv(W_sel);
        EEG_fallback.icaact = [];
    end
end
end

function scalp_idx = get_scalp_channel_indices(EEG)
scalp_idx = [];
if ~isfield(EEG, 'chanlocs') || isempty(EEG.chanlocs)
    return;
end

if isfield(EEG.chanlocs, 'type')
    scalp_idx = find(strcmpi({EEG.chanlocs.type}, 'EEG'));
end

if ~isempty(scalp_idx)
    return;
end

chan_labels = lower(strtrim({EEG.chanlocs.labels}));
exclude_patterns = {'eog', 'vertical', 'horizontal', 'mastoid', 'status'};
exclude_exact = {'heog', 'veog', 'm1', 'm2', 'a1', 'a2'};

keep_mask = true(1, numel(chan_labels));
for idx = 1:numel(chan_labels)
    label = chan_labels{idx};
    if any(strcmp(label, exclude_exact))
        keep_mask(idx) = false;
        continue;
    end
    for pattern_idx = 1:numel(exclude_patterns)
        if contains(label, exclude_patterns{pattern_idx})
            keep_mask(idx) = false;
            break;
        end
    end
end

scalp_idx = find(keep_mask);
end

function EEG = normalize_icachansind_metadata(EEG)
if ~isfield(EEG, 'icaweights') || ~isfield(EEG, 'icasphere') || ...
   isempty(EEG.icaweights) || isempty(EEG.icasphere)
    return;
end

% Build a common channel dimension across ICA fields.
n_weights = size(EEG.icaweights, 2);
n_sphere_r = size(EEG.icasphere, 1);
n_sphere_c = size(EEG.icasphere, 2);
target_cols = min([n_weights, n_sphere_r, n_sphere_c, EEG.nbchan]);

if target_cols <= 0
    return;
end

% Trim ICA matrices so the model is algebraically consistent.
EEG.icaweights = EEG.icaweights(:, 1:target_cols);
EEG.icasphere = EEG.icasphere(1:target_cols, 1:target_cols);

% Recompute inverse weights from the normalized unmixing matrix.
W = EEG.icaweights * EEG.icasphere;
EEG.icawinv = pinv(W);
EEG.icaact = [];

if ~isfield(EEG, 'icachansind') || isempty(EEG.icachansind)
    EEG.icachansind = 1:target_cols;
    return;
end

icachansind = EEG.icachansind(:)';
icachansind = icachansind(icachansind >= 1 & icachansind <= EEG.nbchan);

if numel(icachansind) < target_cols
    extras = setdiff(1:EEG.nbchan, icachansind, 'stable');
    n_needed = min(target_cols - numel(icachansind), numel(extras));
    icachansind = [icachansind extras(1:n_needed)];
end

if numel(icachansind) > target_cols
    icachansind = icachansind(1:target_cols);
end

if isempty(icachansind)
    icachansind = 1:target_cols;
end

EEG.icachansind = icachansind;
end

end