function PrepareData_6_ExtractConditions(Sub, cfg)

%% Unified Step 6: Extract Conditions
% AUTO-DETECTS condition type (Action vs No-Action) and calls appropriate function
% PROCESSES ALL POST-ICA FILES found for this subject
% UPDATED: Extended epoch windows (-500 to +850ms) for complete P2 analysis post motor-subtraction

% Initialize EEGLAB
eeglab nogui;

% --------------------------------------------------------------
% Build configuration from repository paths
% --------------------------------------------------------------
cfgPath = GetFilePathsAndInitializeToolboxes;
repoRoot = cfgPath.PATH.PreprocPath;

% Input: post-ICA continuous datasets
if ~isfield(cfg, 'PathInEEG') || isempty(cfg.PathInEEG)
    cfg.PathInEEG = fullfile(repoRoot, 'sample_datasets', 'continuous datasets', filesep);
end

% Output: per-block epoched sets (consumed by PrepareData_7_ComputeERPs)
if ~isfield(cfg, 'OUTPath') || isempty(cfg.OUTPath)
    cfg.OUTPath = fullfile(repoRoot, 'eeglab_epochs_per_block', Sub, filesep);
end

% create output directory
if ~isfolder(cfg.OUTPath)
   mkdir(cfg.OUTPath); 
end

% --------------------------------------------------------------
% Find ALL post-ICA files for this subject
% --------------------------------------------------------------
fprintf('\n=== Searching for all post-ICA files for %s ===\n', Sub);

all_files = dir([cfg.PathInEEG Sub '_ses-*_task-*_eeg_post_ICA.set']);

if isempty(all_files)
    error('No post-ICA files found for %s in %s', Sub, cfg.PathInEEG);
end

fprintf('Found %d file(s) to process:\n', length(all_files));
for i = 1:length(all_files)
    fprintf('  %d. %s\n', i, all_files(i).name);
end

% --------------------------------------------------------------
% Process EACH file found
% --------------------------------------------------------------
for file_idx = 1:length(all_files)
    
    current_file = all_files(file_idx).name;
    
    fprintf('\n\n========================================\n');
    fprintf('=== Processing File %d of %d ===\n', file_idx, length(all_files));
    fprintf('=== %s ===\n', current_file);
    fprintf('========================================\n\n');
    
    % Update cfg for this specific file
    cfg.FileInEEG = current_file;
    
    % Extract EEGsourceName from filename
    tokens = regexp(current_file, [Sub '(_ses-\d+_task-\w+_eeg)'], 'tokens');
    if ~isempty(tokens)
        cfg.EEGsourceName = tokens{1}{1};
    end
    
    % --------------------------------------------------------------
    % Load the EEG file
    % --------------------------------------------------------------
    fprintf('Loading: %s\n', current_file);
    fprintf('Path: %s\n', cfg.PathInEEG);
    
    [EEG, com] = pop_loadset(cfg.FileInEEG, cfg.PathInEEG);
    EEG = eegh(com, EEG);
    EEG.data = double(EEG.data);
    
    [EEG, com] = eeg_checkset( EEG );
    EEG = eegh(com, EEG);
    
    % Check that data is continuous
    if ndims(EEG.data) == 3
        error('Data is already epoched! This script expects continuous data.');
    end
    
    fprintf('Loaded continuous data: %d channels, %d samples (%.1f seconds)\n', ...
        EEG.nbchan, EEG.pnts, EEG.pnts/EEG.srate);
    
    % Save the original channel locations
    original_chanlocs = EEG.chanlocs;
    
    % --------------------------------------------------------------
    % AUTO-DETECT: Action or No-Action condition?
    % --------------------------------------------------------------
    fprintf('\n=== AUTO-DETECTING CONDITION TYPE ===\n');
    
    has_action_keypress = false;
    has_baseline_marker = false;
    
    for e = 1:length(EEG.event)
        event_type = EEG.event(e).type;
        if ischar(event_type)
            % Check for Action-specific events (multiple possible names)
            if strcmp(event_type, 'ACTION_KEYPRESS') || strcmp(event_type, 'Key_Press')
                has_action_keypress = true;
            elseif strcmp(event_type, 'BASELINE_START') || strcmp(event_type, 'Baseline_Block')
                has_baseline_marker = true;
            end
        end
        if has_action_keypress && has_baseline_marker
            break;  % Found both, no need to keep searching
        end
    end
    
    is_action_condition = has_action_keypress || has_baseline_marker;
    
    % --------------------------------------------------------------
    % Call appropriate extraction function
    % --------------------------------------------------------------
    if is_action_condition
        fprintf('✓ DETECTED: ACTION CONDITION\n');
        fprintf('  Strategy: Extract baseline (keypress-locked) + adaptation/main (tone-locked)\n');
        if isfield(cfg, 'epoch_tmin') && isfield(cfg, 'epoch_tmax')
            fprintf('  Tone-locked epoch window from cfg: %.0f to %.0f ms\n\n', ...
                cfg.epoch_tmin * 1000, cfg.epoch_tmax * 1000);
        else
            fprintf('  Tone-locked epoch window will use extraction defaults\n\n');
        end
        
        % Call ACTION extraction function
        extract_action_condition(EEG, Sub, cfg, original_chanlocs);
        
    else
        fprintf('✓ DETECTED: NO-ACTION CONDITION\n');
        fprintf('  Strategy: Extract adaptation/main (tone-locked, first 100 vs rest)\n');
        if isfield(cfg, 'epoch_tmin') && isfield(cfg, 'epoch_tmax')
            fprintf('  Tone-locked epoch window from cfg: %.0f to %.0f ms\n\n', ...
                cfg.epoch_tmin * 1000, cfg.epoch_tmax * 1000);
        else
            fprintf('  Tone-locked epoch window will use extraction defaults\n\n');
        end
        
        % Call NO-ACTION extraction function
        extract_noaction_condition(EEG, Sub, cfg, original_chanlocs);
    end
    
    fprintf('\n=== File %d of %d COMPLETE ===\n', file_idx, length(all_files));
    
end

fprintf('\n\n========================================\n');
fprintf('=== ALL FILES PROCESSED FOR %s ===\n', Sub);
fprintf('========================================\n');

end