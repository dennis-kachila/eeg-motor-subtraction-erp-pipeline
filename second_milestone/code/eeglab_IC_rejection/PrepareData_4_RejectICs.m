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
[EEG, com] = pop_loadset(input_file, input_path);
EEG = eegh(com, EEG);
EEG.data = double(EEG.data);
    
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
    EEG = pop_iclabel(EEG, 'default');
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