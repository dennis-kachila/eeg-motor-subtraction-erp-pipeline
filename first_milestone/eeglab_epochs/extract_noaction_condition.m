function extract_noaction_condition(EEG, Sub, cfg, original_chanlocs)
%% Extract No-Action Condition: Adaptation (first N) + Main (rest)
%
% ALL datasets saved RAW — no baseline correction applied here.
% Final baseline [-200, 0ms re tone] is applied in PrepareData_7_ComputeERPs
% for adaptation, and in subtract_motor_and_compute_difference for main.
% This ensures identical baseline treatment across all conditions.
%
% Epoch window: cfg.epoch_tmin to cfg.epoch_tmax (tone-locked)
%               e.g. -450ms to +650ms re tone

if ~isfield(cfg, 'epoch_tmin'),   cfg.epoch_tmin   = -0.45; end
if ~isfield(cfg, 'epoch_tmax'),   cfg.epoch_tmax   =  0.65; end
if ~isfield(cfg, 'n_adaptation'), cfg.n_adaptation = 100;   end

fprintf('  Epoch window: %.0f to %.0f ms\n', cfg.epoch_tmin*1000, cfg.epoch_tmax*1000);

%% =========================================================================
%% STEP 1: Epoch ALL tone events (tone-locked, RAW)
%% =========================================================================
fprintf('\n=== STEP 1: Epoch all tone events (tone-locked) ===\n');

EEG_all          = pop_epoch(EEG, {'Tone_Low', 'Tone_Med', 'Tone_High'}, ...
    [cfg.epoch_tmin  cfg.epoch_tmax], 'epochinfo', 'yes');
EEG_all.chanlocs = original_chanlocs;

fprintf('Total epochs created: %d [%.0f to %.0f ms] — RAW\n', ...
    EEG_all.trials, EEG_all.times(1), EEG_all.times(end));

all_event_types = {EEG_all.event.type};
fprintf('Tone counts:\n');
fprintf('  Tone_Low:  %d\n', sum(strcmp(all_event_types, 'Tone_Low')));
fprintf('  Tone_Med:  %d\n', sum(strcmp(all_event_types, 'Tone_Med')));
fprintf('  Tone_High: %d\n', sum(strcmp(all_event_types, 'Tone_High')));

%% =========================================================================
%% STEP 2: Split into adaptation (first N) and main (rest)
%% =========================================================================
fprintf('\n=== STEP 2: Split into adaptation and main ===\n');

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
%% STEP 3: Save ADAPTATION dataset (RAW)
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

    filename = [Sub cfg.EEGsourceName '_adaptation.set'];
    SaveMyData(EEG_adapt, filename, cfg.OUTPath);
    fprintf('Saved: %s\n', filename);
end

%% =========================================================================
%% STEP 4: Save MAIN dataset (RAW)
%% Baseline [-200, 0ms re tone] applied in subtract_motor_and_compute_difference
%% =========================================================================
if ~isempty(main_trials)
    fprintf('\n=== Saving main dataset (RAW) ===\n');

    EEG_main = pop_select(EEG_all, 'trial', main_trials);

    main_epoch_types = get_epoch_types(EEG_main);
    fprintf('Main tone counts (by epoch):\n');
    fprintf('  Tone_Low:  %d\n', sum(strcmp(main_epoch_types, 'Tone_Low')));
    fprintf('  Tone_Med:  %d\n', sum(strcmp(main_epoch_types, 'Tone_Med')));
    fprintf('  Tone_High: %d\n', sum(strcmp(main_epoch_types, 'Tone_High')));

    filename = [Sub cfg.EEGsourceName '_main.set'];
    SaveMyData(EEG_main, filename, cfg.OUTPath);
    fprintf('Saved: %s\n', filename);
end

end


%% =========================================================================
%% HELPER: Get tone type for each epoch
%% =========================================================================
function epoch_types = get_epoch_types(EEG)
    epoch_types = cell(1, EEG.trials);
    tone_types  = {'Tone_Low','Tone_Med','Tone_High'};
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