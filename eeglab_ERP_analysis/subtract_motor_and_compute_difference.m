function subtract_motor_and_compute_difference(Sub, cfg)
%% subtract_motor_and_compute_difference
%
% Motor-contamination removal and difference-wave computation for the
% temporal binding / auditory ERP analysis.
%
% =========================================================================
% RATIONALE
% =========================================================================
% In the ACTION condition the participant presses a key 250 ms before the
% tone. The ERP time-locked to the tone is therefore contaminated by:
%   - The Movement-Related Cortical Potential (MRCP / Bereitschaftspotential)
%   - The motor N1 (response to the efference copy of the movement)
%   - Any other motor-locked neural activity
%
% These motor components overlap directly with the auditory N1 (80-150 ms)
% and P2 (150-275 ms) windows we want to measure.
%
% TEMPLATE SUBTRACTION (Voss et al. 2006; Timm et al. 2014):
%   1. Average all baseline-block keypress epochs  → motor ERP template
%      (Baseline block: keypresses with NO subsequent tone)
%   2. For each main-block trial:
%         cleaned(t) = raw_keypress_epoch(t) − motor_template(t)
%      Both are keypress-locked, same window → subtraction is
%      sample-for-sample aligned. This removes the consistent motor
%      component while preserving the (uncorrelated) auditory response.
%   3. Re-epoch the cleaned signal to TONE ONSET (+250 ms from keypress)
%      → tone-locked, motor-subtracted epochs for N1/P2 analysis
%   4. Baseline correct BOTH Action and NoAction with [-200, 0ms] re tone
%      → identical treatment for valid comparison
%
% BASELINE CORRECTION STRATEGY:
%   Both Action (motor-subtracted) and NoAction main datasets are saved RAW
%   from PrepareData_6. Final baseline correction [-200, 0ms re tone] is
%   applied HERE to both, ensuring the comparison is not confounded by
%   different baseline windows or timing of correction.
%
% DIFFERENCE WAVE:
%   After subtraction both action and no-action epochs are tone-locked.
%   ΔW = Action_motor_subtracted − NoAction
%   A negative deflection in the N1 window indicates N1 suppression in
%   the action condition (efference copy / predictive coding signature).
%
% =========================================================================
% INPUTS
%   Sub  : subject ID string, e.g. 'sub-01'
%   cfg  : configuration struct (from GetConfig). Must include path fields.
%
% OUTPUTS (all saved to eeglab_ERPs/Sub/)
%   Sub_ses-02_task-action_eeg_main_action_motor_subtracted.set
%       Motor-subtracted, tone-locked, baseline-corrected action epochs
%   Sub_ses-01_task-no-action_eeg_main_bc.set
%       Baseline-corrected no-action epochs (same [-200, 0ms] window)
%   Sub_difference_wave_motor_subtracted.mat
%       Difference wave struct: per-tone and collapsed, with times vector
%   Figures:
%       Sub_motor_template.png
%       Sub_action_main_motor_subtracted.png
%       Sub_diff_wave_motor_subtracted_per_tone.png
%       Sub_diff_wave_motor_subtracted_all.png
%
% =========================================================================
% REFERENCES
%   Voss M et al. (2006). Altered awareness of action in schizophrenia:
%     a specific deficit in predicting action consequences. Brain 129:2384-96.
%   Timm J et al. (2014). Motor-auditory temporal binding: the attenuation
%     of N1 is sensitivity to concurrent motor activity. Brain Res 1559:68-78.
%   Haggard P & Eimer M (1999). On the relation between brain potentials and
%     the awareness of voluntary movements. Exp Brain Res 126:128-133.
% =========================================================================

fprintf('\n========================================\n');
fprintf('=== MOTOR SUBTRACTION PIPELINE: %s ===\n', Sub);
fprintf('========================================\n\n');

%% --- Path setup ---
cfgPath  = GetFilePathsAndInitializeToolboxes;
epo_path = fullfile(cfgPath.PATH.PreprocPath, 'eeglab_epochs_per_block', Sub, filesep);
out_path = fullfile(cfgPath.PATH.PreprocPath, 'eeglab_ERPs',             Sub, filesep);
fig_path = fullfile(out_path, 'figures', filesep);

if ~exist(out_path, 'dir'), mkdir(out_path); end
if ~exist(fig_path, 'dir'), mkdir(fig_path); end

%% --- Fixed parameters ---
% Keypress-to-tone delay (seconds). Must match your paradigm exactly.
kp_to_tone  =  0.250;

% FINAL baseline for tone-locked epochs (ms, pre-tone).
% Applied to BOTH Action and NoAction after all processing.
tone_bsl_ms = [-200  0];

% Motor baseline window (ms, pre-keypress).
% Conservative window well before any motor activity.
% Safe for epoch starting at -200ms re keypress (i.e. -450ms re tone).
motor_bsl_ms_fixed = [-150  -50];

% Channels for summary plots
plot_chans = {'FCz','FC1','FC2','FC3','FC4','Fz','F1','F2','Cz','C1','C2','C3','CPz'};

% Tone types
tone_types  = {'Tone_Low', 'Tone_Med', 'Tone_High'};
tone_labels = {'Low',      'Med',      'High'};
tone_colors = {[0.2 0.4 0.8], [0.8 0.3 0.1], [0.1 0.6 0.3]};

%% =========================================================================
%% STEP 1: Load files
%% =========================================================================
fprintf('--- STEP 1: Loading epoch sets ---\n');

% Action baseline (keypress-locked, pure motor, no BC)
f_bsl = [Sub '_ses-02_task-action_eeg_baseline_action.set'];
if ~exist(fullfile(epo_path, f_bsl), 'file')
    error('Baseline action file not found:\n  %s\nRun PrepareData_6 first.', fullfile(epo_path, f_bsl));
end
EEG_bsl = pop_loadset(f_bsl, epo_path);
EEG_bsl.data = double(EEG_bsl.data);
fprintf('  Baseline action:     %d keypress-locked epochs\n', EEG_bsl.trials);
fprintf('  Epoch window: [%.0f  %.0f] ms re keypress\n', EEG_bsl.times(1), EEG_bsl.times(end));

% Validate motor baseline window fits inside epoch
motor_bsl_ms = motor_bsl_ms_fixed;
if motor_bsl_ms(1) < EEG_bsl.times(1) || motor_bsl_ms(2) > EEG_bsl.times(end)
    pre_kp_ms    = abs(EEG_bsl.times(1));
    motor_bsl_ms = [-(pre_kp_ms)  -(pre_kp_ms * 0.7)];
    motor_bsl_ms(1) = max(motor_bsl_ms(1), EEG_bsl.times(1) + 1);
    motor_bsl_ms(2) = min(motor_bsl_ms(2), EEG_bsl.times(end) - 1);
    fprintf('  WARNING: Fixed motor baseline [%.0f %.0f ms] outside epoch window.\n', ...
        motor_bsl_ms_fixed(1), motor_bsl_ms_fixed(2));
    fprintf('  Using fallback motor baseline: [%.0f  %.0f] ms\n', motor_bsl_ms(1), motor_bsl_ms(2));
else
    fprintf('  Motor baseline window: [%.0f  %.0f] ms (pre-keypress)\n', motor_bsl_ms(1), motor_bsl_ms(2));
end

if diff(motor_bsl_ms) < 20
    error('Motor baseline window is too narrow (%.0f ms).', diff(motor_bsl_ms));
end

% Action main (tone-locked, RAW - no BC)
f_main_ac = [Sub '_ses-02_task-action_eeg_main_action.set'];
if ~exist(fullfile(epo_path, f_main_ac), 'file')
    error('Main action file not found:\n  %s\nRun PrepareData_6 first.', fullfile(epo_path, f_main_ac));
end
EEG_main_ac = pop_loadset(f_main_ac, epo_path);
EEG_main_ac.data = double(EEG_main_ac.data);
fprintf('  Main action (raw):   %d tone-locked epochs\n', EEG_main_ac.trials);

% Action adaptation
f_adap_ac = [Sub '_ses-02_task-action_eeg_adaptation_action.set'];
has_adap_ac = exist(fullfile(epo_path, f_adap_ac), 'file');
if has_adap_ac
    EEG_adap_ac = pop_loadset(f_adap_ac, epo_path);
    EEG_adap_ac.data = double(EEG_adap_ac.data);
    fprintf('  Adaptation action:   %d tone-locked epochs\n', EEG_adap_ac.trials);
end

% No-action main (tone-locked, RAW - no BC)
f_main_na = [Sub '_ses-01_task-no-action_eeg_main.set'];
if ~exist(fullfile(epo_path, f_main_na), 'file')
    error('No-action main file not found:\n  %s\nRun PrepareData_6 first.', fullfile(epo_path, f_main_na));
end
EEG_main_na = pop_loadset(f_main_na, epo_path);
EEG_main_na.data = double(EEG_main_na.data);
fprintf('  Main no-action (raw): %d tone-locked epochs\n', EEG_main_na.trials);

% No-action adaptation
f_adap_na = [Sub '_ses-01_task-no-action_eeg_adaptation.set'];
has_adap_na = exist(fullfile(epo_path, f_adap_na), 'file');

% NOTE: Baseline is keypress-locked [-200 to +900ms re keypress]
%       Main action is tone-locked  [-450 to +650ms re tone]
%       These are the SAME physical window (keypress 250ms before tone).
%       Alignment is verified after the time-shift in Step 3.

%% =========================================================================
%% STEP 2: Build motor ERP template from baseline keypresses
%% =========================================================================
fprintf('\n--- STEP 2: Building motor ERP template ---\n');

fprintf('  Applying pre-keypress baseline to template: [%.0f  %.0f] ms\n', ...
    motor_bsl_ms(1), motor_bsl_ms(2));
EEG_bsl_bc = pop_rmbase(EEG_bsl, motor_bsl_ms);

% Average across all baseline trials → motor ERP template [nChan × nTime]
motor_template = mean(EEG_bsl_bc.data, 3);
fprintf('  Motor template: %d channels × %d timepoints  (from %d baseline trials)\n', ...
    size(motor_template,1), size(motor_template,2), EEG_bsl.trials);

plot_motor_template(motor_template, EEG_bsl.times, EEG_bsl.chanlocs, ...
    plot_chans, Sub, fig_path);

%% =========================================================================
%% STEP 3: Convert tone-locked main epochs to keypress-locked by time-shift
%% =========================================================================
fprintf('\n--- STEP 3: Converting main action epochs to keypress-locked ---\n');

kp_offset_ms = kp_to_tone * 1000;   % 250 ms

EEG_kp       = EEG_main_ac;
EEG_kp.times = EEG_main_ac.times - kp_offset_ms;
EEG_kp.xmin  = EEG_kp.times(1)   / 1000;
EEG_kp.xmax  = EEG_kp.times(end) / 1000;

fprintf('  Tone-locked window:     [%.0f  %.0f] ms re tone\n', ...
    EEG_main_ac.times(1), EEG_main_ac.times(end));
fprintf('  Keypress-locked window: [%.0f  %.0f] ms re keypress\n', ...
    EEG_kp.times(1), EEG_kp.times(end));

% Verify alignment with template after shift
if abs(EEG_kp.times(1) - EEG_bsl.times(1)) > 5 || ...
   abs(EEG_kp.times(end) - EEG_bsl.times(end)) > 5
    warning(['After time-shift, windows still differ:\n' ...
        '  Main (shifted): [%.0f  %.0f] ms\n' ...
        '  Template:       [%.0f  %.0f] ms\n' ...
        'Check that kp_to_tone (%.3f s) matches your paradigm.'], ...
        EEG_kp.times(1), EEG_kp.times(end), ...
        EEG_bsl.times(1), EEG_bsl.times(end), kp_to_tone);
else
    fprintf('  ✓ Windows aligned after shift: Main=[%.0f %.0f] Template=[%.0f %.0f] ms\n', ...
        EEG_kp.times(1), EEG_kp.times(end), EEG_bsl.times(1), EEG_bsl.times(end));
end

% Align template to main epoch window
align_idx = find(EEG_bsl.times >= EEG_kp.times(1), 1, 'first');
if isempty(align_idx)
    error('Main epochs start at %.0f ms but template starts at %.0f ms - no overlap!', ...
        EEG_kp.times(1), EEG_bsl.times(1));
end

n_samples_main         = length(EEG_kp.times);
motor_template_aligned = motor_template(:, align_idx:end);

if size(motor_template_aligned, 2) < n_samples_main
    n_pad = n_samples_main - size(motor_template_aligned, 2);
    motor_template_aligned = [motor_template_aligned, zeros(size(motor_template,1), n_pad)];
    fprintf('  Aligned and padded motor template: %d samples (added %d zero samples)\n', ...
        size(motor_template_aligned,2), n_pad);
elseif size(motor_template_aligned, 2) > n_samples_main
    motor_template_aligned = motor_template_aligned(:, 1:n_samples_main);
    fprintf('  Aligned and trimmed motor template: %d samples\n', size(motor_template_aligned,2));
else
    fprintf('  Aligned motor template: %d samples (perfect match)\n', size(motor_template_aligned,2));
end
motor_template = motor_template_aligned;

% Apply motor baseline to main epochs (keypress-locked)
kp_bsl_clamped(1) = max(motor_bsl_ms(1), EEG_kp.times(1)   + 1);
kp_bsl_clamped(2) = min(motor_bsl_ms(2), EEG_kp.times(end) - 1);
if kp_bsl_clamped(1) >= kp_bsl_clamped(2)
    error('Motor baseline window [%.0f %.0f ms] does not fit in epoch [%.0f %.0f ms].', ...
        motor_bsl_ms(1), motor_bsl_ms(2), EEG_kp.times(1), EEG_kp.times(end));
end
fprintf('  Applying motor baseline to main epochs: [%.0f  %.0f] ms\n', ...
    kp_bsl_clamped(1), kp_bsl_clamped(2));
EEG_kp_bc = pop_rmbase(EEG_kp, kp_bsl_clamped);

%% =========================================================================
%% STEP 4: ERP-level template subtraction (keypress-locked)
%%
%% Subtracts motor template from the AVERAGED ERP per tone type, not from
%% individual trials. This avoids over-cancellation caused by trial-to-trial
%% variability in motor timing/amplitude.
%%
%% Per-tone: average within each tone type → subtract template → replace all
%%           trials of that tone with the cleaned ERP (preserves epoch structure
%%           for downstream per-tone N1/P2 analysis)
%% Collapsed: average across ALL tones → subtract template once → used for
%%            grand average difference wave
%% =========================================================================
fprintf('\n--- STEP 4: ERP-level motor template subtraction ---\n');

if size(motor_template,2) ~= size(EEG_kp_bc.data,2)
    error('Motor template has %d timepoints but main epochs have %d timepoints.', ...
        size(motor_template,2), size(EEG_kp_bc.data,2));
end

EEG_subtracted = EEG_kp_bc;

% --- Per-tone subtraction ---
for tt = 1:length(tone_types)
    mask = get_tone_epoch_mask(EEG_kp_bc, tone_types{tt});
    n_tone = sum(mask);
    if n_tone == 0
        warning('No epochs found for %s — skipping.', tone_types{tt});
        continue;
    end
    % Average within this tone type then subtract template
    tone_erp_clean = mean(EEG_kp_bc.data(:,:,mask), 3) - motor_template;  % [nChan x nTime]
    % Replace all trials of this tone with the cleaned ERP
    EEG_subtracted.data(:,:,mask) = repmat(tone_erp_clean, [1 1 n_tone]);
    fprintf('  %s: averaged %d epochs → subtracted template ✓\n', tone_types{tt}, n_tone);
end

% --- Collapsed subtraction (all tones) ---
% Average across ALL epochs regardless of tone type, subtract template once
collapsed_erp_clean = mean(EEG_kp_bc.data, 3) - motor_template;  % [nChan x nTime]
% Store as a separate field for use in Step 7 grand average difference wave
EEG_subtracted.collapsed_erp_clean = collapsed_erp_clean;

fprintf('  ERP-level subtraction complete (%d total epochs, %d tone types).\n', ...
    EEG_kp_bc.trials, length(tone_types));

%% =========================================================================
%% STEP 5: Convert back to TONE-LOCKED by shifting time axis
%% =========================================================================
fprintf('\n--- STEP 5: Converting to tone-locked (time axis shift) ---\n');

EEG_tone        = EEG_subtracted;
EEG_tone.times  = EEG_subtracted.times + kp_offset_ms;   % +250ms
EEG_tone.xmin   = EEG_tone.times(1)  / 1000;
EEG_tone.xmax   = EEG_tone.times(end)/ 1000;

% Shift collapsed ERP time axis too (same operation, no data change needed)
% collapsed_erp_clean shares the same time axis as EEG_subtracted

fprintf('  Keypress-locked: [%.0f  %.0f] ms\n', EEG_subtracted.times(1), EEG_subtracted.times(end));
fprintf('  Tone-locked:     [%.0f  %.0f] ms (shifted by +%.0f ms)\n', ...
    EEG_tone.times(1), EEG_tone.times(end), kp_offset_ms);
if EEG_tone.times(end) >= 275
    fprintf('  Post-tone coverage: %.0f ms (P2 window 150-275ms: FULL ✓)\n', EEG_tone.times(end));
else
    fprintf('  WARNING: Post-tone coverage only %.0f ms (P2 window may be clipped)\n', EEG_tone.times(end));
end

%% =========================================================================
%% STEP 6: Apply FINAL baseline correction to BOTH conditions [-200, 0ms re tone]
%% =========================================================================
fprintf('\n--- STEP 6: Applying final baseline [%.0f  %.0f ms re tone] to both conditions ---\n', ...
    tone_bsl_ms(1), tone_bsl_ms(2));

% --- Action (motor-subtracted, tone-locked) ---
tone_bsl_ac(1) = max(tone_bsl_ms(1), EEG_tone.times(1)   + 1);
tone_bsl_ac(2) = min(tone_bsl_ms(2), EEG_tone.times(end) - 1);
EEG_tone_bc    = pop_rmbase(EEG_tone, tone_bsl_ac);
fprintf('  Action:    baseline [%.0f  %.0f ms] applied ✓\n', tone_bsl_ac(1), tone_bsl_ac(2));

% Apply same baseline correction to collapsed ERP
bsl_idx = find(EEG_tone.times >= tone_bsl_ac(1) & EEG_tone.times <= tone_bsl_ac(2));
if ~isempty(bsl_idx) && isfield(EEG_tone, 'collapsed_erp_clean')
    bsl_mean = mean(EEG_tone.collapsed_erp_clean(:, bsl_idx), 2);
    EEG_tone_bc.collapsed_erp_clean = EEG_tone.collapsed_erp_clean - bsl_mean;
    fprintf('  Collapsed ERP: baseline [%.0f  %.0f ms] applied ✓\n', tone_bsl_ac(1), tone_bsl_ac(2));
end

fname_ac = [Sub '_ses-02_task-action_eeg_main_action_motor_subtracted.set'];
SaveMyData(EEG_tone_bc, fname_ac, out_path);
fprintf('  Saved: %s\n', fname_ac);

% --- NoAction (tone-locked, raw → now baseline corrected) ---
tone_bsl_na(1) = max(tone_bsl_ms(1), EEG_main_na.times(1)   + 1);
tone_bsl_na(2) = min(tone_bsl_ms(2), EEG_main_na.times(end) - 1);
EEG_main_na_bc = pop_rmbase(EEG_main_na, tone_bsl_na);
fprintf('  NoAction:  baseline [%.0f  %.0f ms] applied ✓\n', tone_bsl_na(1), tone_bsl_na(2));

fname_na = [Sub '_ses-01_task-no-action_eeg_main_bc.set'];
SaveMyData(EEG_main_na_bc, fname_na, out_path);
fprintf('  Saved: %s\n', fname_na);

plot_subtracted_action(EEG_tone_bc, Sub, plot_chans, tone_types, tone_labels, tone_colors, fig_path);

%% =========================================================================
%% STEP 7: Compute difference wave  (Action_subtracted − NoAction)
%% =========================================================================
fprintf('\n--- STEP 7: Computing difference wave ---\n');

% Both datasets are now tone-locked and baseline corrected with [-200, 0ms]
% Verify time axes match
if abs(EEG_tone_bc.times(1) - EEG_main_na_bc.times(1)) > 2 || ...
   abs(EEG_tone_bc.times(end) - EEG_main_na_bc.times(end)) > 2
    warning(['Action and no-action epoch windows do not match exactly:\n' ...
        '  Action:    [%.0f  %.0f] ms\n' ...
        '  No-action: [%.0f  %.0f] ms\n' ...
        'Interpolating no-action to match action time axis.'], ...
        EEG_tone_bc.times(1), EEG_tone_bc.times(end), ...
        EEG_main_na_bc.times(1), EEG_main_na_bc.times(end));
    na_erp_all    = mean(EEG_main_na_bc.data, 3);
    na_erp_interp = interp1(EEG_main_na_bc.times, na_erp_all', EEG_tone_bc.times, 'linear')';
    times = EEG_tone_bc.times;
else
    na_erp_interp = [];
    times = EEG_tone_bc.times;
end

if isstruct(EEG_tone_bc.chanlocs)
    chan_labels = {EEG_tone_bc.chanlocs.labels};
else
    chan_labels = EEG_tone_bc.chanlocs;
end

roi_chans = {'FCz','FC1','FC2','FC3','FC4','Fz','F1','F2','Cz','C1','C2','C3','CPz'};
roi_idx   = [];
for ch = 1:length(roi_chans)
    idx = find(strcmp(chan_labels, roi_chans{ch}));
    if ~isempty(idx), roi_idx(end+1) = idx(1); end %#ok<AGROW>
end
if isempty(roi_idx)
    warning('No ROI channels found — using all channels for difference wave.');
    roi_idx = 1:EEG_tone_bc.nbchan;
end
fprintf('  ROI: %d channels (%s)\n', length(roi_idx), strjoin(chan_labels(roi_idx), ', '));

diff_waves       = struct();
diff_waves.times = times;

for tt = 1:length(tone_types)
    tone_lbl = tone_labels{tt};
    tone_typ = tone_types{tt};

    % Action ERP for this tone
    ac_ep = get_tone_epoch_mask(EEG_tone_bc, tone_typ);
    if any(ac_ep)
        ac_erp_roi = squeeze(mean(mean(EEG_tone_bc.data(roi_idx, :, ac_ep), 1), 3));
    else
        ac_erp_roi = zeros(1, length(times));
        warning('No %s epochs in motor-subtracted action data.', tone_typ);
    end

    % NoAction ERP for this tone
    na_ep = get_tone_epoch_mask(EEG_main_na_bc, tone_typ);
    if isempty(na_erp_interp)
        if any(na_ep)
            na_erp_roi = squeeze(mean(mean(EEG_main_na_bc.data(roi_idx, :, na_ep), 1), 3));
        else
            na_erp_roi = zeros(1, length(times));
            warning('No %s epochs in no-action data.', tone_typ);
        end
    else
        na_erp_roi = squeeze(mean(na_erp_interp(roi_idx, :), 1));
    end

    diff_waves.(tone_lbl)                = ac_erp_roi - na_erp_roi;
    diff_waves.([tone_lbl '_n_action'])  = sum(ac_ep);
    diff_waves.([tone_lbl '_n_noaction'])= sum(na_ep);

    fprintf('  %s:  Action n=%d  NoAction n=%d\n', tone_typ, sum(ac_ep), sum(na_ep));
end

% Collapsed across all tone types — use the dedicated collapsed ERP
% (averaged across ALL epochs before subtraction, not re-averaged here)
if isfield(EEG_tone_bc, 'collapsed_erp_clean')
    ac_all = squeeze(mean(EEG_tone_bc.collapsed_erp_clean(roi_idx, :), 1));
    fprintf('  Using collapsed_erp_clean for grand average difference wave ✓\n');
else
    ac_all = squeeze(mean(mean(EEG_tone_bc.data(roi_idx, :, :), 3), 1));
    fprintf('  WARNING: collapsed_erp_clean not found, falling back to epoch average\n');
end
if isempty(na_erp_interp)
    na_all = squeeze(mean(mean(EEG_main_na_bc.data(roi_idx, :, :), 3), 1));
else
    na_all = squeeze(mean(na_erp_interp(roi_idx, :), 1));
end
diff_waves.All             = ac_all - na_all;
diff_waves.All_n_action    = EEG_tone_bc.trials;
diff_waves.All_n_noaction  = EEG_main_na_bc.trials;
diff_waves.roi_channels    = chan_labels(roi_idx);
diff_waves.baseline_window = tone_bsl_ms;

save(fullfile(out_path, [Sub '_difference_wave_motor_subtracted.mat']), 'diff_waves');
fprintf('  Saved: %s_difference_wave_motor_subtracted.mat\n', Sub);

%% =========================================================================
%% STEP 8: Plot difference waves
%% =========================================================================
fprintf('\n--- STEP 8: Plotting difference waves ---\n');
plot_difference_waves(diff_waves, tone_labels, tone_colors, Sub, fig_path);

fprintf('\n========================================\n');
fprintf('=== MOTOR SUBTRACTION COMPLETE: %s ===\n', Sub);
fprintf('========================================\n\n');

end


%% =========================================================================
%% LOCAL HELPER: boolean mask of epochs matching a tone type
%% =========================================================================
function mask = get_tone_epoch_mask(EEG, tone_type)
    mask = false(1, EEG.trials);
    for ep = 1:EEG.trials
        ev_types = EEG.epoch(ep).eventtype;
        if ~iscell(ev_types), ev_types = {ev_types}; end
        ev_lats  = EEG.epoch(ep).eventlatency;
        if ~iscell(ev_lats),  ev_lats  = {ev_lats};  end
        for ii = 1:length(ev_lats)
            if isnumeric(ev_lats{ii}) && abs(ev_lats{ii}) < 1e-6
                if strcmp(ev_types{ii}, tone_type)
                    mask(ep) = true;
                    break;
                end
            end
        end
        if ~mask(ep) && any(strcmp(ev_types, tone_type))
            mask(ep) = true;
        end
    end
end


%% =========================================================================
%% LOCAL HELPER: plot motor template
%% =========================================================================
function plot_motor_template(template, times, chanlocs, plot_chans, Sub, fig_path)
    if isstruct(chanlocs)
        chan_labels = {chanlocs.labels};
    else
        chan_labels = chanlocs;
    end
    fig = figure('Position', [100 100 1000 500], 'Visible', 'off');
    hold on;
    colors = lines(length(plot_chans));
    for c = 1:length(plot_chans)
        idx = find(strcmp(chan_labels, plot_chans{c}));
        if ~isempty(idx)
            plot(times, template(idx(1), :), 'Color', colors(c,:), ...
                'LineWidth', 1.5, 'DisplayName', plot_chans{c});
        end
    end
    yline(0, 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
    xline(0, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Keypress');
    set(gca, 'YDir', 'reverse');
    xlabel('Time re: keypress (ms)', 'FontSize', 12);
    ylabel('Amplitude (µV)  [negative up]', 'FontSize', 12);
    title(sprintf('%s  |  Motor ERP Template (baseline keypresses)', Sub), 'FontSize', 13);
    legend('Location', 'southeast', 'FontSize', 9);
    xlim([times(1) times(end)]); grid on; hold off;
    saveas(fig, fullfile(fig_path, [Sub '_motor_template.png']));
    close(fig);
    fprintf('  Saved: motor_template.png\n');
end


%% =========================================================================
%% LOCAL HELPER: plot motor-subtracted action ERP
%% =========================================================================
function plot_subtracted_action(EEG, Sub, plot_chans, tone_types, tone_labels, tone_colors, fig_path)
    if isstruct(EEG.chanlocs)
        chan_labels = {EEG.chanlocs.labels};
    else
        chan_labels = EEG.chanlocs;
    end
    fig = figure('Position', [100 100 1000 500], 'Visible', 'off');
    hold on;
    for tt = 1:length(tone_types)
        mask = false(1, EEG.trials);
        for ep = 1:EEG.trials
            ev = EEG.epoch(ep).eventtype;
            if ~iscell(ev), ev = {ev}; end
            if any(strcmp(ev, tone_types{tt})), mask(ep) = true; end
        end
        if ~any(mask), continue; end
        fc_chans = {'FCz','FC1','FC2','Fz','Cz'};
        fc_idx   = [];
        for ch = fc_chans
            idx = find(strcmp(chan_labels, ch{1}));
            if ~isempty(idx), fc_idx(end+1) = idx(1); end %#ok<AGROW>
        end
        if isempty(fc_idx), fc_idx = 1:EEG.nbchan; end
        erp = squeeze(mean(mean(EEG.data(fc_idx,:,mask),1),3));
        plot(EEG.times, erp, 'Color', tone_colors{tt}, 'LineWidth', 2.0, ...
            'DisplayName', tone_labels{tt});
    end
    yline(0, 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
    xline(0, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Tone onset');
    patch([80 150 150 80],   [-100 -100 100 100], [0.8 0.8 1],   'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    patch([150 275 275 150], [-100 -100 100 100], [1 0.9 0.8],   'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    set(gca, 'YDir', 'reverse');
    xlabel('Time re: tone (ms)', 'FontSize', 12);
    ylabel('Amplitude (µV)  [negative up]', 'FontSize', 12);
    title(sprintf('%s  |  Motor-subtracted Action ERP', Sub), 'FontSize', 13);
    legend('Location', 'southeast', 'FontSize', 10);
    xlim([EEG.times(1) EEG.times(end)]); grid on; hold off;
    saveas(fig, fullfile(fig_path, [Sub '_action_main_motor_subtracted.png']));
    close(fig);
    fprintf('  Saved: action_main_motor_subtracted.png\n');
end


%% =========================================================================
%% LOCAL HELPER: plot difference waves
%% =========================================================================
function plot_difference_waves(diff_waves, tone_labels, tone_colors, Sub, fig_path)
    times = diff_waves.times;
    fig1 = figure('Position', [100 100 950 550], 'Visible', 'off');
    hold on;
    for tt = 1:length(tone_labels)
        lbl = tone_labels{tt};
        if ~isfield(diff_waves, lbl), continue; end
        n_ac = diff_waves.([lbl '_n_action']);
        n_na = diff_waves.([lbl '_n_noaction']);
        plot(times, diff_waves.(lbl), 'Color', tone_colors{tt}, 'LineWidth', 2.0, ...
            'DisplayName', sprintf('%s (Ac n=%d, NA n=%d)', lbl, n_ac, n_na));
    end
    yline(0, 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');
    xline(0, 'r--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    add_erp_shading(gca);
    set(gca, 'YDir', 'reverse');
    xlabel('Time re: tone (ms)', 'FontSize', 12);
    ylabel('Amplitude (µV)  [Action − NoAction, negative up]', 'FontSize', 12);
    title(sprintf('%s  |  Difference Wave per Tone (Motor-subtracted Action − NoAction)', Sub), 'FontSize', 12);
    legend('Location', 'southeast', 'FontSize', 10);
    xlim([times(1) times(end)]); grid on; hold off;
    saveas(fig1, fullfile(fig_path, [Sub '_diff_wave_motor_subtracted_per_tone.png']));
    close(fig1);

    fig2 = figure('Position', [100 100 950 500], 'Visible', 'off');
    hold on;
    plot(times, diff_waves.All, 'k-', 'LineWidth', 2.5, ...
        'DisplayName', sprintf('All tones (Ac n=%d, NA n=%d)', ...
        diff_waves.All_n_action, diff_waves.All_n_noaction));
    yline(0, 'k--', 'LineWidth', 0.8, 'HandleVisibility', 'off');
    xline(0, 'r--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    add_erp_shading(gca);
    set(gca, 'YDir', 'reverse');
    xlabel('Time re: tone (ms)', 'FontSize', 12);
    ylabel('Amplitude (µV)  [Action − NoAction, negative up]', 'FontSize', 12);
    title(sprintf('%s  |  Difference Wave Collapsed (Motor-subtracted Action − NoAction)', Sub), 'FontSize', 12);
    legend('Location', 'southeast', 'FontSize', 10);
    xlim([times(1) times(end)]); grid on; hold off;
    saveas(fig2, fullfile(fig_path, [Sub '_diff_wave_motor_subtracted_all.png']));
    close(fig2);
    fprintf('  Saved: diff_wave_per_tone.png and diff_wave_all.png\n');
end


%% =========================================================================
%% LOCAL HELPER: shade N1 and P2 windows on current axes
%% =========================================================================
function add_erp_shading(ax)
    yl = ylim(ax);
    patch(ax, [80 150 150 80],   [yl(1) yl(1) yl(2) yl(2)], [0.8 0.8 1.0], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    patch(ax, [150 275 275 150], [yl(1) yl(1) yl(2) yl(2)], [1.0 0.9 0.8], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    text(ax, 115, yl(1)*0.9, 'N1', 'FontSize', 9, 'Color', [0.3 0.3 0.8]);
    text(ax, 200, yl(1)*0.9, 'P2', 'FontSize', 9, 'Color', [0.8 0.5 0.2]);
end