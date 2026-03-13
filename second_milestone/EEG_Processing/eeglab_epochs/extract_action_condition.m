function extract_action_condition(EEG, Sub, cfg, original_chanlocs)
%% Extract Action Condition: Baseline keypresses + Adaptation + Main
%
% ALL datasets saved RAW — no baseline correction applied here.
% Final baseline [-200, 0ms re tone] is applied in PrepareData_7_ComputeERPs
% for adaptation, and in subtract_motor_and_compute_difference for main.
% This ensures identical baseline treatment across all conditions.
%
% Epoch windows (same physical data, different reference point):
%   Keypress-locked (baseline block): cfg.epoch_tmin_motor to cfg.epoch_tmax_motor
%                                     e.g. -200ms to +900ms re keypress
%   Tone-locked (adaptation, main):   cfg.epoch_tmin to cfg.epoch_tmax
%                                     e.g. -450ms to +650ms re tone
%   These are equivalent: -200ms re keypress = -450ms re tone (keypress 250ms before tone)

if ~isfield(cfg, 'epoch_tmin'),       cfg.epoch_tmin       = -0.45; end
if ~isfield(cfg, 'epoch_tmax'),       cfg.epoch_tmax       =  0.65; end
if ~isfield(cfg, 'epoch_tmin_motor'), cfg.epoch_tmin_motor = -0.20; end
if ~isfield(cfg, 'epoch_tmax_motor'), cfg.epoch_tmax_motor =  0.90; end
if ~isfield(cfg, 'n_adaptation'),     cfg.n_adaptation     = 100;   end

fprintf('  Tone-locked epoch window:     %.0f to %.0f ms\n', cfg.epoch_tmin*1000, cfg.epoch_tmax*1000);
fprintf('  Keypress-locked epoch window: %.0f to %.0f ms\n', cfg.epoch_tmin_motor*1000, cfg.epoch_tmax_motor*1000);

%% =========================================================================
%% STEP 1: Extract BASELINE keypresses (keypress-locked, pure motor, RAW)
%% =========================================================================
fprintf('\n=== STEP 1: Extract baseline keypresses (pure motor) ===\n');

all_events     = {EEG.event.type};
baseline_idx   = find(strcmp(all_events, 'Baseline_Block'));
adaptation_idx = find(strcmp(all_events, 'Adaptation_Block'));

if ~isempty(baseline_idx) && ~isempty(adaptation_idx)

    baseline_start_lat   = EEG.event(baseline_idx).latency;
    adaptation_start_lat = EEG.event(adaptation_idx).latency;

    fprintf('  Baseline block: %.1f to %.1f seconds\n', ...
        baseline_start_lat/EEG.srate, adaptation_start_lat/EEG.srate);

    % Extract continuous data from baseline block only
    EEG_baseline_block          = pop_select(EEG, 'point', ...
        [round(baseline_start_lat)  round(adaptation_start_lat - 1)]);
    EEG_baseline_block.chanlocs = original_chanlocs;

    fprintf('  Baseline block: %d samples (%.1f seconds)\n', ...
        EEG_baseline_block.pnts, EEG_baseline_block.pnts/EEG_baseline_block.srate);

    % Epoch around keypresses — keypress-locked window
    EEG_baseline          = pop_epoch(EEG_baseline_block, {'Key_Press'}, ...
        [cfg.epoch_tmin_motor  cfg.epoch_tmax_motor], 'epochinfo', 'yes');
    EEG_baseline.chanlocs = original_chanlocs;

    fprintf('  Created %d baseline keypress epochs [%.0f to %.0f ms] — RAW\n', ...
        EEG_baseline.trials, EEG_baseline.times(1), EEG_baseline.times(end));

    if EEG_baseline.trials > 0
        filename = [Sub '_ses-02_task-action_eeg_baseline_action.set'];
        SaveMyData(EEG_baseline, filename, cfg.OUTPath);
        fprintf('  Saved: %s\n', filename);
    else
        warning('No baseline keypress epochs created!');
    end

else
    warning('Baseline_Block or Adaptation_Block marker not found — skipping baseline extraction.');
end

%% =========================================================================
%% STEP 2: Epoch ALL tone events (tone-locked, RAW)
%% =========================================================================
fprintf('\n=== STEP 2: Epoch all tone events (tone-locked) ===\n');

EEG_all          = pop_epoch(EEG, {'Tone_Low', 'Tone_Med', 'Tone_High'}, ...
    [cfg.epoch_tmin  cfg.epoch_tmax], 'epochinfo', 'yes');
EEG_all.chanlocs = original_chanlocs;

fprintf('Total tone epochs created: %d [%.0f to %.0f ms] — RAW\n', ...
    EEG_all.trials, EEG_all.times(1), EEG_all.times(end));

all_event_types = {EEG_all.event.type};
fprintf('Tone counts:\n');
fprintf('  Tone_Low:  %d\n', sum(strcmp(all_event_types, 'Tone_Low')));
fprintf('  Tone_Med:  %d\n', sum(strcmp(all_event_types, 'Tone_Med')));
fprintf('  Tone_High: %d\n', sum(strcmp(all_event_types, 'Tone_High')));

%% =========================================================================
%% STEP 3: Split into adaptation (first N) and main (rest)
%% =========================================================================
fprintf('\n=== STEP 3: Split into adaptation and main ===\n');

n_total      = EEG_all.trials;
n_adaptation = min(cfg.n_adaptation, n_total);
adapt_trials = 1:n_adaptation;
main_trials  = (n_adaptation+1):n_total;
if n_total <= n_adaptation
    main_trials = [];
end

fprintf('Adaptation: trials 1-%d (%d epochs)\n', n_adaptation, length(adapt_trials));
fprintf('Main: trials %d-%d (%d epochs)\n', n_adaptation+1, n_total, length(main_trials));

%% =========================================================================
%% STEP 4: Save ADAPTATION dataset (RAW)
%% Baseline [-200, 0ms re tone] applied in PrepareData_7_ComputeERPs
%% =========================================================================
if ~isempty(adapt_trials)
    fprintf('\n=== Saving adaptation dataset (RAW) ===\n');

    EEG_adapt = pop_select(EEG_all, 'trial', adapt_trials);

    adapt_epoch_types = get_epoch_types(EEG_adapt);
    fprintf('Adaptation tone counts (by epoch):\n');
    fprintf('  Tone_Low:  %d\n', sum(strcmp(adapt_epoch_types, 'Tone_Low')));
    fprintf('  Tone_Med:  %d\n', sum(strcmp(adapt_epoch_types, 'Tone_Med')));
    fprintf('  Tone_High: %d\n', sum(strcmp(adapt_epoch_types, 'Tone_High')));

    filename = [Sub '_ses-02_task-action_eeg_adaptation_action.set'];
    SaveMyData(EEG_adapt, filename, cfg.OUTPath);
    fprintf('Saved: %s\n', filename);
end

%% =========================================================================
%% STEP 5: Save MAIN dataset (RAW)
%% Baseline [-200, 0ms re tone] applied in subtract_motor_and_compute_difference
%% after motor subtraction
%% =========================================================================
if ~isempty(main_trials)
    fprintf('\n=== Saving main dataset (RAW) ===\n');

    EEG_main = pop_select(EEG_all, 'trial', main_trials);

    main_epoch_types = get_epoch_types(EEG_main);
    fprintf('Main tone counts (by epoch):\n');
    fprintf('  Tone_Low:  %d\n', sum(strcmp(main_epoch_types, 'Tone_Low')));
    fprintf('  Tone_Med:  %d\n', sum(strcmp(main_epoch_types, 'Tone_Med')));
    fprintf('  Tone_High: %d\n', sum(strcmp(main_epoch_types, 'Tone_High')));

    filename = [Sub '_ses-02_task-action_eeg_main_action.set'];
    SaveMyData(EEG_main, filename, cfg.OUTPath);
    fprintf('Saved: %s\n', filename);
end

fprintf('\n=== Action condition extraction complete ===\n');

end


%% =========================================================================
%% HELPER: Get tone type for each epoch
%% =========================================================================
function epoch_types = get_epoch_types(EEG)
    epoch_types = cell(1, EEG.trials);
    tone_types  = {'Tone_Low', 'Tone_Med', 'Tone_High'};
    for ev = 1:length(EEG.event)
        t = EEG.event(ev).type;
        if ~ischar(t), continue; end
        if ~any(strcmp(t, tone_types)), continue; end
        ep = EEG.event(ev).epoch;
        if ep < 1 || ep > EEG.trials, continue; end
        if isempty(epoch_types{ep})
            epoch_types{ep} = t;
        end
    end
end