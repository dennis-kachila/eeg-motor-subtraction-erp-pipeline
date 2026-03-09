function PrepareData_7_ComputeERPs(Sub, cfg)
%% Computes N1/P2/P50 ERPs for both conditions, saves figures + .mat results.
%
% ERP figures: single plot per block, frontal+central electrodes averaged,
%              Low/Med/High tone lines, NEGATIVE UP,
%              shaded windows centered on actual peak latencies
% Topo figures: P50, N1, P2 scalp maps (electrodes within head only)
% No Adapt-vs-Main plots.

fprintf('\n=== Computing ERPs for %s ===\n', Sub);

cfgPath  = GetFilePathsAndInitializeToolboxes;
epo_path = [cfgPath.PATH.PreprocPath 'eeglab_epochs_per_block' filesep Sub filesep];
out_path = [cfgPath.PATH.PreprocPath 'eeglab_ERPs' filesep Sub filesep];
fig_path = [out_path 'figures' filesep];

if ~exist(out_path, 'dir'), mkdir(out_path); end
if ~exist(fig_path, 'dir'), mkdir(fig_path); end

%% NO-ACTION CONDITION
fprintf('\n--- No-Action Condition ---\n');
na_adapt = load_set(epo_path, [Sub '_ses-01_task-no-action_eeg_adaptation.set']);
na_main  = load_set(epo_path, [Sub '_ses-01_task-no-action_eeg_main.set']);

if ~isempty(na_adapt) || ~isempty(na_main)
    results_noaction = compute_N1_P2(na_adapt, na_main, 'NoAction');
    save([out_path Sub '_ERP_results_noaction.mat'], 'results_noaction');
    if ~isempty(na_adapt)
        peaks = get_grand_peaks(na_adapt);
        plot_erp( na_adapt, peaks, Sub, 'NoAction', 'Adaptation', fig_path);
        plot_topo(na_adapt, peaks, Sub, 'NoAction_Adaptation', fig_path);
    end
    if ~isempty(na_main)
        peaks = get_grand_peaks(na_main);
        plot_erp( na_main, peaks, Sub, 'NoAction', 'Main', fig_path);
        plot_topo(na_main, peaks, Sub, 'NoAction_Main', fig_path);
    end
else
    fprintf('  No no-action epoch files found\n');
end

%% ACTION CONDITION
fprintf('\n--- Action Condition ---\n');
ac_adapt    = load_set(epo_path, [Sub '_ses-02_task-action_eeg_adaptation_action.set']);
ac_main     = load_set(epo_path, [Sub '_ses-02_task-action_eeg_main_action.set']);
ac_baseline = load_set(epo_path, [Sub '_ses-02_task-action_eeg_baseline_action.set']);

% Run motor subtraction FIRST (if action files exist)
if ~isempty(ac_main) && ~isempty(ac_baseline)
    fprintf('\n--- Running Motor Subtraction ---\n');
    try
        subtract_motor_and_compute_difference(Sub, struct());
        fprintf('Motor subtraction complete.\n');
        
        % Reload the motor-subtracted main file
        ac_main_motor_file = [out_path Sub '_ses-02_task-action_eeg_main_action_motor_subtracted.set'];
        if exist(ac_main_motor_file, 'file')
            ac_main = pop_loadset(ac_main_motor_file);
            fprintf('  Loaded motor-subtracted action main: %d epochs\n', ac_main.trials);
        else
            fprintf('  Warning: Motor-subtracted file not found, using raw action data\n');
        end
    catch ME
        fprintf('  Motor subtraction failed: %s\n', ME.message);
        fprintf('  Continuing with raw action data...\n');
    end
end

if ~isempty(ac_adapt) || ~isempty(ac_main)
    results_action = compute_N1_P2(ac_adapt, ac_main, 'Action');
    save([out_path Sub '_ERP_results_action.mat'], 'results_action');
    if ~isempty(ac_adapt)
        peaks = get_grand_peaks(ac_adapt);
        plot_erp( ac_adapt, peaks, Sub, 'Action', 'Adaptation', fig_path);
        plot_topo(ac_adapt, peaks, Sub, 'Action_Adaptation', fig_path);
    end
    if ~isempty(ac_main)
        peaks = get_grand_peaks(ac_main);
        plot_erp( ac_main, peaks, Sub, 'Action', 'Main', fig_path);
        plot_topo(ac_main, peaks, Sub, 'Action_Main', fig_path);
    end
    if ~isempty(ac_baseline)
        peaks = get_grand_peaks(ac_baseline);
        plot_erp(ac_baseline, peaks, Sub, 'Action', 'Baseline_Keypress', fig_path);
    end
else
    fprintf('  No action epoch files found\n');
end

%% COMPARISON PLOTS (Action vs No-Action)
fprintf('\n--- Creating Action vs No-Action Comparison Plots ---\n');
try
    plot_action_noaction_comparison(Sub);
    fprintf('Comparison plots created successfully.\n');
catch ME
    fprintf('  Comparison plotting failed: %s\n', ME.message);
end

% Save per-subject Excel to the ERP output folder
results_noaction_safe = [];
results_action_safe   = [];
if exist('results_noaction','var'), results_noaction_safe = results_noaction; end
if exist('results_action','var'),   results_action_safe   = results_action;   end
save_subject_excel(Sub, out_path, results_noaction_safe, results_action_safe);

fprintf('\nDone computing ERPs for %s.\n\n', Sub);
end


%% =========================================================
function EEG = load_set(base_path, filename)
    if exist([base_path filename], 'file')
        EEG = pop_loadset(filename, base_path);
        fprintf('  Loaded: %s (%d epochs)\n', filename, EEG.trials);
    else
        fprintf('  Not found: %s\n', filename);
        EEG = [];
    end
end


%% =========================================================
function chan_idx = get_chan_idx(EEG, electrodes)
    chan_labs = {EEG.chanlocs.labels};
    chan_idx  = [];
    for e = 1:length(electrodes)
        idx = find(strcmp(chan_labs, electrodes{e}));
        if ~isempty(idx), chan_idx = [chan_idx idx(1)]; end
    end
end


%% =========================================================
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


%% =========================================================
%% get_grand_peaks  - compute P50/N1/P2 peak latencies from
%%                    grand average (all tones, all channels)
%%                    Used to centre shaded windows in plots.
%% =========================================================
function peaks = get_grand_peaks(EEG)

    all_elecs = {'FCz','FC1','FC2','FC3','FC4','Fz','F1','F2','Cz','C1','C2','C3','CPz'};
    chan_idx = get_chan_idx(EEG, all_elecs);
    if isempty(chan_idx), chan_idx = 1:min(32, EEG.nbchan); end

    % Grand average across all epochs and channels
    erp   = squeeze(mean(mean(EEG.data(chan_idx, :, :), 3), 1));
    times = EEG.times;

    % Search windows
    P50_win = [30  80];
    N1_win  = [80  150];
    P2_win  = [150 275];
    half_w  = 20;   % half-width of shaded band around peak (ms)

    function [pk_lat, lo, hi] = find_peak(erp, times, win, polarity)
        idx = find(times >= win(1) & times <= win(2));
        if polarity > 0
            [~, rel] = max(erp(idx));
        else
            [~, rel] = min(erp(idx));
        end
        pk_lat = times(idx(rel));
        lo     = pk_lat - half_w;
        hi     = pk_lat + half_w;
    end

    [peaks.P50_lat, peaks.P50_lo, peaks.P50_hi] = find_peak(erp, times, P50_win, +1);
    [peaks.N1_lat,  peaks.N1_lo,  peaks.N1_hi ] = find_peak(erp, times, N1_win,  -1);
    [peaks.P2_lat,  peaks.P2_lo,  peaks.P2_hi ] = find_peak(erp, times, P2_win,  +1);

    fprintf('    Grand peaks  P50=%.0fms  N1=%.0fms  P2=%.0fms\n', ...
        peaks.P50_lat, peaks.N1_lat, peaks.P2_lat);
end


%% =========================================================
%% plot_erp  - Low/Med/High lines, windows centred on peaks
%% =========================================================
function plot_erp(EEG, peaks, Sub, condition, block_name, fig_path)

    all_elecs = {'FCz','FC1','FC2','FC3','FC4','Fz','F1','F2','Cz','C1','C2','C3','CPz'};
    chan_idx = get_chan_idx(EEG, all_elecs);
    if isempty(chan_idx), return; end

    tone_types  = {'Tone_Low',  'Tone_Med',  'Tone_High'};
    tone_labels = {'Low',       'Medium',    'High'};
    tone_colors = {[0 0 0.85],  [0 0.65 0], [0.85 0 0]};

    fig = figure('Position', [100 100 950 620], 'Visible', 'off');
    hold on;

    has_tones = false;
    for t = 1:length(tone_types)
        erp = get_erp_by_tone(EEG, chan_idx, tone_types{t});
        if isempty(erp), continue; end
        plot(EEG.times, erp, 'Color', tone_colors{t}, 'LineWidth', 2.0, ...
            'DisplayName', tone_labels{t});
        has_tones = true;
    end
    if ~has_tones
        all_ev = {};
        for ep = 1:EEG.trials
            ev = EEG.epoch(ep).eventtype;
            if iscell(ev), all_ev = [all_ev ev];
            else, all_ev{end+1} = ev; end
        end
        fprintf('  WARNING: No Tone_Low/Med/High found in %s %s\n', condition, block_name);
        fprintf('  Unique event types present: %s\n', strjoin(unique(all_ev), ', '));
        erp = squeeze(mean(mean(EEG.data(chan_idx,:,:), 3), 1));
        plot(EEG.times, erp, 'k-', 'LineWidth', 2.0, 'DisplayName', 'All');
    end

   % Set fixed y-axis limits for consistency
    ylim([-10 10]);
    yl = [-10 10];

    % Shaded windows centred on actual peak latencies
    fill([peaks.P50_lo peaks.P50_hi peaks.P50_hi peaks.P50_lo], ...
         [yl(1) yl(1) yl(2) yl(2)], ...
         [0.3 0.8 0.3], 'FaceAlpha', 0.13, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([peaks.N1_lo peaks.N1_hi peaks.N1_hi peaks.N1_lo], ...
         [yl(1) yl(1) yl(2) yl(2)], ...
         [0.55 0.55 0.55], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    fill([peaks.P2_lo peaks.P2_hi peaks.P2_hi peaks.P2_lo], ...
         [yl(1) yl(1) yl(2) yl(2)], ...
         [0.45 0.45 1.0], 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');

    % Vertical lines at peak latencies
    xline(peaks.P50_lat, '-', 'Color', [0.2 0.7 0.2], 'LineWidth', 1.2, 'HandleVisibility', 'off');
    xline(peaks.N1_lat,  '-', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2, 'HandleVisibility', 'off');
    xline(peaks.P2_lat,  '-', 'Color', [0.3 0.3 0.8], 'LineWidth', 1.2, 'HandleVisibility', 'off');

    % Stimulus onset
    xline(0, 'r--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

    % Labels at top (= bottom in negative-up = yl(2))
    text(peaks.P50_lat, yl(2)-0.03*diff(yl), sprintf('P50\n%.0fms', peaks.P50_lat), ...
        'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.1 0.6 0.1]);
    text(peaks.N1_lat,  yl(2)-0.03*diff(yl), sprintf('N1\n%.0fms',  peaks.N1_lat), ...
        'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.35 0.35 0.35]);
    text(peaks.P2_lat,  yl(2)-0.03*diff(yl), sprintf('P2\n%.0fms',  peaks.P2_lat), ...
        'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.25 0.25 0.75]);

    set(gca, 'YDir', 'reverse');
    xlabel('Time (ms)', 'FontSize', 12);
    ylabel('Amplitude (\muV)', 'FontSize', 12);
    title(sprintf('Grand Average - Frontal+Central Electrodes (%s %s Block)', condition, block_name), 'FontSize', 13);
    legend('Location', 'southeast', 'FontSize', 10);
    xlim([-100 500]);
    grid on;
    hold off;

    saveas(fig, [fig_path Sub '_' condition '_' block_name '_grand_average.png']);
    close(fig);
    fprintf('  Saved: %s_%s_%s_grand_average.png\n', Sub, condition, block_name);
end


%% =========================================================
%% plot_topo  - P50, N1, P2 scalp maps at peak latencies
%% =========================================================

function plot_topo(EEG, peaks, Sub, label, fig_path)
    times   = EEG.times;
    n_scalp = min(64, EEG.nbchan);

    get_topo = @(lat) mean(EEG.data(1:n_scalp, find(times >= lat, 1, 'first'), :), 3);
    P50_topo = get_topo(peaks.P50_lat);
    N1_topo  = get_topo(peaks.N1_lat);
    P2_topo  = get_topo(peaks.P2_lat);

    % Auto-scale each component to its own data range
    % Symmetric around zero
    make_clim = @(topo) [-1 1] * max(max(abs(topo)), 1);
    clim_P50 = make_clim(P50_topo);
    clim_N1  = make_clim(N1_topo);
    clim_P2  = make_clim(P2_topo);

    topo_args = {'electrodes', 'on', 'style', 'map', 'shading', 'interp', ...
                 'plotrad', 0.5, 'headrad', 0.5, 'intrad', 0.5};

    fig = figure('Position', [100 100 1500 480], 'Visible', 'off');

    subplot(1,3,1);
    topoplot(P50_topo, EEG.chanlocs(1:n_scalp), topo_args{:});
    title(sprintf('P50  (%.0f ms)', peaks.P50_lat), 'FontSize', 12);
    clim(clim_P50);
    colorbar;

    subplot(1,3,2);
    topoplot(N1_topo, EEG.chanlocs(1:n_scalp), topo_args{:});
    title(sprintf('N1  (%.0f ms)', peaks.N1_lat), 'FontSize', 12);
    clim(clim_N1);
    colorbar;

    subplot(1,3,3);
    topoplot(P2_topo, EEG.chanlocs(1:n_scalp), topo_args{:});
    title(sprintf('P2  (%.0f ms)', peaks.P2_lat), 'FontSize', 12);
    clim(clim_P2);
    colorbar;

    sgtitle(sprintf('%s  |  %s', Sub, strrep(label,'_',' ')), 'FontSize', 13);
    saveas(fig, [fig_path Sub '_' label '_topography.png']);
    close(fig);
    fprintf('  Saved: %s_%s_topography.png\n', Sub, label);
end
%% =========================================================
%% save_subject_excel  - saves per-subject ERP results to Excel
%%   Rows: Condition x Tone (NoAction_Main + Action_Main only)
%%   Saved to: eeglab_ERPs/sub-XX/sub-XX_ERP_results.xlsx
%% =========================================================
function save_subject_excel(Sub, out_path, results_noaction, results_action)

    tone_types  = {'Tone_Low', 'Tone_Med', 'Tone_High'};
    tone_labels = {'Low',      'Medium',   'High'};

    headers = {'Subject', 'Condition', 'Tone', ...
               'N1_Peak_Amp_uV', 'N1_Peak_Lat_ms', 'N1_Mean_Amp_uV_80-150', ...
               'P2_Peak_Amp_uV', 'P2_Peak_Lat_ms', 'P2_Mean_Amp_uV_150-275', ...
               'P50_Peak_Amp_uV', 'P50_Peak_Lat_ms', ...
               'N_Epochs'};
    rows = {};

    % --- NoAction Main ---
    if ~isempty(results_noaction) && isfield(results_noaction, 'Main') && ...
            ~isempty(results_noaction.Main)
        for t = 1:length(tone_types)
            pk = get_tone_peaks(results_noaction.Main, tone_types{t});
            rows(end+1,:) = {Sub, 'NoAction_Main', tone_labels{t}, ...
                pk.N1_peak_amp, pk.N1_peak_lat, pk.N1_mean_amp, ...
                pk.P2_peak_amp, pk.P2_peak_lat, pk.P2_mean_amp, ...
                pk.P50_peak_amp, pk.P50_peak_lat, ...
                pk.n_epochs};
        end
    end

    % --- Action Main ---
    if ~isempty(results_action) && isfield(results_action, 'Main') && ...
            ~isempty(results_action.Main)
        for t = 1:length(tone_types)
            pk = get_tone_peaks(results_action.Main, tone_types{t});
            rows(end+1,:) = {Sub, 'Action_Main', tone_labels{t}, ...
                pk.N1_peak_amp, pk.N1_peak_lat, pk.N1_mean_amp, ...
                pk.P2_peak_amp, pk.P2_peak_lat, pk.P2_mean_amp, ...
                pk.P50_peak_amp, pk.P50_peak_lat, ...
                pk.n_epochs};
        end
    end

    if isempty(rows)
        fprintf('  No Main block results to save for %s\n', Sub);
        return;
    end

    T = cell2table(rows, 'VariableNames', headers);

    % Save CSV (reliable fallback)
    csv_file = [out_path Sub '_ERP_results.csv'];
    writetable(T, csv_file);
    fprintf('  Saved CSV: %s_ERP_results.csv\n', Sub);

    % Save Excel
    xlsx_file = [out_path Sub '_ERP_results.xlsx'];
    try
        writetable(T, xlsx_file, 'Sheet', 'Main_Blocks');
        fprintf('  Saved Excel: %s_ERP_results.xlsx\n', Sub);
    catch ME
        fprintf('  Excel write failed (%s) - CSV saved instead\n', ME.message);
    end
end


%% =========================================================
function pk = get_tone_peaks(block_results, tone_type)
    % Returns peak struct for a specific tone from block_results.PerTone
    tone_map = struct('Tone_Low','Low', 'Tone_Med','Med', 'Tone_High','High');
    
    pk.N1_peak_amp  = NaN; pk.N1_peak_lat  = NaN; pk.N1_mean_amp = NaN;
    pk.P2_peak_amp  = NaN; pk.P2_peak_lat  = NaN; pk.P2_mean_amp = NaN;
    pk.P50_peak_amp = NaN; pk.P50_peak_lat = NaN;
    pk.n_epochs     = 0;

    if isfield(tone_map, tone_type) && isfield(block_results, 'PerTone')
        tf = tone_map.(tone_type);
        if isfield(block_results.PerTone, tf)
            src = block_results.PerTone.(tf);
            if isfield(src, 'N1_peak_amp'),  pk.N1_peak_amp  = src.N1_peak_amp;  end
            if isfield(src, 'N1_peak_lat'),  pk.N1_peak_lat  = src.N1_peak_lat;  end
            if isfield(src, 'P2_peak_amp'),  pk.P2_peak_amp  = src.P2_peak_amp;  end
            if isfield(src, 'P2_peak_lat'),  pk.P2_peak_lat  = src.P2_peak_lat;  end
            if isfield(src, 'P50_peak_amp'), pk.P50_peak_amp = src.P50_peak_amp; end
            if isfield(src, 'P50_peak_lat'), pk.P50_peak_lat = src.P50_peak_lat; end
            if isfield(src, 'N1_mean_amp'),  pk.N1_mean_amp  = src.N1_mean_amp;  end
            if isfield(src, 'P2_mean_amp'),  pk.P2_mean_amp  = src.P2_mean_amp;  end
            if isfield(src, 'n_epochs'),     pk.n_epochs     = src.n_epochs;     end
            return;
        end
    end

    % Fallback: use aggregate electrode group (Fz priority)
    for g = {'Fz','FCz','Cz','Frontal','Central'}
        gn = g{1};
        if isfield(block_results, gn)
            src = block_results.(gn);
            if isfield(src, 'N1_peak_amp'),  pk.N1_peak_amp  = src.N1_peak_amp;  end
            if isfield(src, 'N1_peak_lat'),  pk.N1_peak_lat  = src.N1_peak_lat;  end
            if isfield(src, 'P2_peak_amp'),  pk.P2_peak_amp  = src.P2_peak_amp;  end
            if isfield(src, 'P2_peak_lat'),  pk.P2_peak_lat  = src.P2_peak_lat;  end
            if isfield(src, 'P50_peak_amp'), pk.P50_peak_amp = src.P50_peak_amp; end
            if isfield(src, 'P50_peak_lat'), pk.P50_peak_lat = src.P50_peak_lat; end
            if isfield(src, 'N1_mean_amp'),  pk.N1_mean_amp  = src.N1_mean_amp;  end
            if isfield(src, 'P2_mean_amp'),  pk.P2_mean_amp  = src.P2_mean_amp;  end
            if isfield(block_results, 'n_epochs'), pk.n_epochs = block_results.n_epochs; end
            return;
        end
    end
end