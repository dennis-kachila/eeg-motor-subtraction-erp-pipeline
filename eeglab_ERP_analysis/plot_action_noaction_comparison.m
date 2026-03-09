function plot_action_noaction_comparison(Sub)
%% PLOT_ACTION_NOACTION_COMPARISON
% Creates two comparison figures:
%   Figure 1: Action vs No-Action (all tones collapsed)
%   Figure 2: Action (3 tones) vs No-Action (3 tones)
%
% Usage: plot_action_noaction_comparison('sub-01')

if nargin < 1
    Sub = 'sub-01';
end

fprintf('\n=== Plotting Action vs No-Action Comparison for %s ===\n', Sub);

% Initialize EEGLAB
eeglab nogui;

% Paths
cfgPath  = GetFilePathsAndInitializeToolboxes;
epo_path = [cfgPath.PATH.PreprocPath 'eeglab_epochs_per_block' filesep Sub filesep];
out_path = [cfgPath.PATH.PreprocPath 'eeglab_ERPs' filesep Sub filesep];
fig_path = [out_path 'figures' filesep];

if ~exist(fig_path, 'dir'), mkdir(fig_path); end

%% Load the epoch files
% No-Action Main
na_file = [epo_path Sub '_ses-01_task-no-action_eeg_main.set'];
if ~exist(na_file, 'file')
    error('No-Action file not found: %s', na_file);
end
EEG_na = pop_loadset(na_file);
fprintf('Loaded No-Action: %d epochs\n', EEG_na.trials);

% Action Main (should be the RAW one before motor subtraction, or use motor-subtracted?)
% Let's use the motor-subtracted one from eeglab_ERPs folder
ac_file_motor = [out_path Sub '_ses-02_task-action_eeg_main_action_motor_subtracted.set'];
if exist(ac_file_motor, 'file')
    EEG_ac = pop_loadset(ac_file_motor);
    fprintf('Loaded Action (motor-subtracted): %d epochs\n', EEG_ac.trials);
else
    % Fallback to non-subtracted
    ac_file = [epo_path Sub '_ses-02_task-action_eeg_main_action.set'];
    if ~exist(ac_file, 'file')
        error('Action file not found');
    end
    EEG_ac = pop_loadset(ac_file);
    fprintf('Loaded Action (raw): %d epochs\n', EEG_ac.trials);
end

%% Get frontal+central electrodes

all_elecs = {'FCz','FC1','FC2','FC3','FC4','Fz','F1','F2','Cz','C1','C2','C3','CPz'};
chan_idx_na = get_chan_idx(EEG_na, all_elecs);
chan_idx_ac = get_chan_idx(EEG_ac, all_elecs);

if isempty(chan_idx_na) || isempty(chan_idx_ac)
    error('Could not find frontal+central electrodes');
end

%% FIGURE 1: Collapsed across all tones
fprintf('\nGenerating Figure 1: Collapsed comparison...\n');

% Get grand average across all epochs
erp_na_all = squeeze(mean(mean(EEG_na.data(chan_idx_na, :, :), 3), 1));
erp_ac_all = squeeze(mean(mean(EEG_ac.data(chan_idx_ac, :, :), 3), 1));

% Find N1 and P2 peaks for shading
N1_window = [80 150];
P2_window = [150 275];

fig1 = figure('Position', [100 100 1600 600], 'Visible', 'off');

% Subplot 1: No-Action
subplot(1, 2, 1);
hold on;

% Set fixed y-limits 
yl = [-10 10];
ylim(yl);

% Add shaded N1 and P2 windows FIRST (so they're behind the line)
fill([N1_window(1) N1_window(2) N1_window(2) N1_window(1)], ...
     [yl(1) yl(1) yl(2) yl(2)], ...
     [0.55 0.55 0.55], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([P2_window(1) P2_window(2) P2_window(2) P2_window(1)], ...
     [yl(1) yl(1) yl(2) yl(2)], ...
     [0.45 0.45 1.0], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Add labels
text(mean(N1_window), yl(2)-0.05, 'N1', ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.35 0.35 0.35], 'FontWeight', 'bold');
text(mean(P2_window), yl(2)-0.05, 'P2', ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.25 0.25 0.75], 'FontWeight', 'bold');

% Plot waveform on top
plot(EEG_na.times, erp_na_all, 'Color', [0 0.45 0.74], 'LineWidth', 2.5);
xline(0, 'r--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

set(gca, 'YDir', 'reverse');
xlabel('Time (ms)', 'FontSize', 12);
ylabel('Amplitude (\muV)', 'FontSize', 12);
title('No-Action Block (All Tones)', 'FontSize', 14, 'FontWeight', 'bold');
xlim([-100 500]);
grid on;
hold off;

% Subplot 2: Action
subplot(1, 2, 2);
hold on;

% Get y-limits for shading
yl = [-10 10];
ylim(yl);

% Add shaded N1 and P2 windows FIRST
fill([N1_window(1) N1_window(2) N1_window(2) N1_window(1)], ...
     [yl(1) yl(1) yl(2) yl(2)], ...
     [0.55 0.55 0.55], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([P2_window(1) P2_window(2) P2_window(2) P2_window(1)], ...
     [yl(1) yl(1) yl(2) yl(2)], ...
     [0.45 0.45 1.0], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Add labels
text(mean(N1_window), yl(2)-0.05, 'N1', ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.35 0.35 0.35], 'FontWeight', 'bold');
text(mean(P2_window), yl(2)-0.05, 'P2', ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.25 0.25 0.75], 'FontWeight', 'bold');

% Plot waveform on top
plot(EEG_ac.times, erp_ac_all, 'Color', [0.85 0.33 0.10], 'LineWidth', 2.5);
xline(0, 'r--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

set(gca, 'YDir', 'reverse');
xlabel('Time (ms)', 'FontSize', 12);
ylabel('Amplitude (\muV)', 'FontSize', 12);
title('Action Block (All Tones, Motor-Subtracted)', 'FontSize', 14, 'FontWeight', 'bold');
xlim([-100 500]);
grid on;
hold off;

sgtitle(sprintf('%s: Action vs No-Action Comparison (Collapsed)', Sub), ...
    'FontSize', 16, 'FontWeight', 'bold');

% Save Figure 1
fig1_file = [fig_path Sub '_Action_vs_NoAction_Collapsed.png'];
saveas(fig1, fig1_file);
close(fig1);
fprintf('Saved: %s\n', fig1_file);

%% FIGURE 2: Per-tone comparison
fprintf('Generating Figure 2: Per-tone comparison...\n');

tone_types  = {'Tone_Low',  'Tone_Med',  'Tone_High'};
tone_labels = {'Low',       'Medium',    'High'};
tone_colors = {[0 0 0.85],  [0 0.65 0],  [0.85 0 0]};

% Get ERPs per tone for No-Action
erp_na_low = get_erp_by_tone(EEG_na, chan_idx_na, 'Tone_Low');
erp_na_med = get_erp_by_tone(EEG_na, chan_idx_na, 'Tone_Med');
erp_na_high = get_erp_by_tone(EEG_na, chan_idx_na, 'Tone_High');

% Get ERPs per tone for Action
erp_ac_low = get_erp_by_tone(EEG_ac, chan_idx_ac, 'Tone_Low');
erp_ac_med = get_erp_by_tone(EEG_ac, chan_idx_ac, 'Tone_Med');
erp_ac_high = get_erp_by_tone(EEG_ac, chan_idx_ac, 'Tone_High');

% N1 and P2 windows
N1_window = [80 150];
P2_window = [150 275];

fig2 = figure('Position', [100 100 1600 600], 'Visible', 'off');

% Subplot 1: No-Action per tone
subplot(1, 2, 1);
hold on;

% Get y-limits
yl = [-10 10];
ylim(yl);

% Add shaded windows FIRST
fill([N1_window(1) N1_window(2) N1_window(2) N1_window(1)], ...
     [yl(1) yl(1) yl(2) yl(2)], ...
     [0.55 0.55 0.55], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([P2_window(1) P2_window(2) P2_window(2) P2_window(1)], ...
     [yl(1) yl(1) yl(2) yl(2)], ...
     [0.45 0.45 1.0], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Add labels
text(mean(N1_window), yl(2)-0.05, 'N1', ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.35 0.35 0.35], 'FontWeight', 'bold');
text(mean(P2_window), yl(2)-0.05, 'P2', ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.25 0.25 0.75], 'FontWeight', 'bold');

% Plot waveforms
if ~isempty(erp_na_low)
    plot(EEG_na.times, erp_na_low, 'Color', tone_colors{1}, 'LineWidth', 2.0, ...
        'DisplayName', tone_labels{1});
end
if ~isempty(erp_na_med)
    plot(EEG_na.times, erp_na_med, 'Color', tone_colors{2}, 'LineWidth', 2.0, ...
        'DisplayName', tone_labels{2});
end
if ~isempty(erp_na_high)
    plot(EEG_na.times, erp_na_high, 'Color', tone_colors{3}, 'LineWidth', 2.0, ...
        'DisplayName', tone_labels{3});
end
xline(0, 'r--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

set(gca, 'YDir', 'reverse');
xlabel('Time (ms)', 'FontSize', 12);
ylabel('Amplitude (\muV)', 'FontSize', 12);
title('No-Action Block', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'southeast', 'FontSize', 10);
xlim([-100 500]);
grid on;
hold off;

% Subplot 2: Action per tone
subplot(1, 2, 2);
hold on;

% Get y-limits
yl = [-10 10];
ylim(yl);

% Add shaded windows FIRST
fill([N1_window(1) N1_window(2) N1_window(2) N1_window(1)], ...
     [yl(1) yl(1) yl(2) yl(2)], ...
     [0.55 0.55 0.55], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([P2_window(1) P2_window(2) P2_window(2) P2_window(1)], ...
     [yl(1) yl(1) yl(2) yl(2)], ...
     [0.45 0.45 1.0], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Add labels
text(mean(N1_window), yl(2)-0.05, 'N1', ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.35 0.35 0.35], 'FontWeight', 'bold');
text(mean(P2_window), yl(2)-0.05, 'P2', ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'Color', [0.25 0.25 0.75], 'FontWeight', 'bold');

% Plot waveforms
if ~isempty(erp_ac_low)
    plot(EEG_ac.times, erp_ac_low, 'Color', tone_colors{1}, 'LineWidth', 2.0, ...
        'DisplayName', tone_labels{1});
end
if ~isempty(erp_ac_med)
    plot(EEG_ac.times, erp_ac_med, 'Color', tone_colors{2}, 'LineWidth', 2.0, ...
        'DisplayName', tone_labels{2});
end
if ~isempty(erp_ac_high)
    plot(EEG_ac.times, erp_ac_high, 'Color', tone_colors{3}, 'LineWidth', 2.0, ...
        'DisplayName', tone_labels{3});
end
xline(0, 'r--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

set(gca, 'YDir', 'reverse');
xlabel('Time (ms)', 'FontSize', 12);
ylabel('Amplitude (\muV)', 'FontSize', 12);
title('Action Block (Motor-Subtracted)', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'southeast', 'FontSize', 10);
xlim([-100 500]);
grid on;
hold off;

sgtitle(sprintf('%s: Action vs No-Action by Tone', Sub), ...
    'FontSize', 16, 'FontWeight', 'bold');

% Save Figure 2
fig2_file = [fig_path Sub '_Action_vs_NoAction_PerTone.png'];
saveas(fig2, fig2_file);
close(fig2);
fprintf('Saved: %s\n', fig2_file);

fprintf('\n=== Comparison figures complete ===\n\n');

end

%% =========================================================
%% Helper functions
%% =========================================================

function chan_idx = get_chan_idx(EEG, electrodes)
    chan_labs = {EEG.chanlocs.labels};
    chan_idx  = [];
    for e = 1:length(electrodes)
        idx = find(strcmp(chan_labs, electrodes{e}));
        if ~isempty(idx), chan_idx = [chan_idx idx(1)]; end
    end
end

function erp = get_erp_by_tone(EEG, chan_idx, tone_type)
    epoch_idx = false(1, EEG.trials);

    % Method 1: use EEG.epoch(ep).eventtype if available
    if ~isempty(EEG.epoch) && isfield(EEG.epoch, 'eventtype')
        for ep = 1:EEG.trials
            ev = EEG.epoch(ep).eventtype;
            if ~iscell(ev), ev = {ev}; end
            for k = 1:length(ev)
                if ischar(ev{k}) && (strcmp(ev{k}, tone_type) || contains(ev{k}, tone_type))
                    epoch_idx(ep) = true; break;
                end
            end
        end
    end

    % Method 2: fall back to EEG.event directly (more reliable)
    if ~any(epoch_idx) && isfield(EEG.event, 'epoch')
        for ev_idx = 1:length(EEG.event)
            ev_type = EEG.event(ev_idx).type;
            if ischar(ev_type) && (strcmp(ev_type, tone_type) || contains(ev_type, tone_type))
                ep_num = EEG.event(ev_idx).epoch;
                if ep_num >= 1 && ep_num <= EEG.trials
                    epoch_idx(ep_num) = true;
                end
            end
        end
    end

    if ~any(epoch_idx), erp = []; return; end
    erp = squeeze(mean(mean(EEG.data(chan_idx, :, epoch_idx), 3), 1));
end