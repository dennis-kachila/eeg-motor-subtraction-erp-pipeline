function compare_N1_P2_amplitudes(Sub, cfg)
%% compare_N1_P2_amplitudes
%
% Compares N1 and P2 peak and mean amplitudes between Adaptation and Main
% blocks for both Action (motor-subtracted) and NoAction conditions.
%
% INPUTS:
%   Sub : subject ID (e.g., 'sub-01')
%   cfg : config structure
%
% OUTPUTS:
%   - CSV file with peak and mean amplitudes for each condition/block
%   - Bar plots comparing amplitudes across blocks
%   - Statistical summary (paired t-tests)
%
% USAGE:
%   Sub = 'sub-01';
%   cfg = struct(); cfg.Pipeline = 3;
%   compare_N1_P2_amplitudes(Sub, cfg);

fprintf('\n========================================\n');
fprintf('=== AMPLITUDE COMPARISON: %s ===\n', Sub);
fprintf('========================================\n\n');

%% Setup paths
cfgPath  = GetFilePathsAndInitializeToolboxes;
epo_path = fullfile(cfgPath.PATH.PreprocPath, 'eeglab_epochs_per_block', Sub, filesep);
out_path = fullfile(cfgPath.PATH.PreprocPath, 'eeglab_ERPs', Sub, filesep);
fig_path = fullfile(out_path, 'figures', filesep);

if ~exist(out_path, 'dir'), mkdir(out_path); end
if ~exist(fig_path, 'dir'), mkdir(fig_path); end

%% Define analysis windows and ROI
N1_window = [80 150];   % ms
P2_window = [150 275];  % ms

% ROI: Frontal-Central electrodes (standard for auditory ERPs)
roi_chans = {'Fz', 'F3', 'F4', 'FCz', 'FC3', 'FC4', 'Cz', 'C3', 'C4'};

%% Load datasets
fprintf('--- Loading datasets ---\n');

% NoAction
na_adapt = load_set(epo_path, [Sub '_ses-01_task-no-action_eeg_adaptation.set']);
na_main  = load_set(epo_path, [Sub '_ses-01_task-no-action_eeg_main.set']);

% Action (motor-subtracted Main, regular Adaptation)
ac_adapt = load_set(epo_path, [Sub '_ses-02_task-action_eeg_adaptation_action.set']);
ac_main  = load_set(epo_path, [Sub '_ses-02_task-action_eeg_main_action_motor_subtracted.set']);

%% Extract amplitudes for each condition/block
fprintf('\n--- Extracting amplitudes ---\n');

results = struct();

% NoAction Adaptation
if ~isempty(na_adapt)
    results.NoAction_Adaptation = extract_amplitudes(na_adapt, roi_chans, N1_window, P2_window);
    fprintf('  NoAction Adaptation: %d epochs\n', na_adapt.trials);
end

% NoAction Main
if ~isempty(na_main)
    results.NoAction_Main = extract_amplitudes(na_main, roi_chans, N1_window, P2_window);
    fprintf('  NoAction Main: %d epochs\n', na_main.trials);
end

% Action Adaptation
if ~isempty(ac_adapt)
    results.Action_Adaptation = extract_amplitudes(ac_adapt, roi_chans, N1_window, P2_window);
    fprintf('  Action Adaptation: %d epochs\n', ac_adapt.trials);
end

% Action Main (motor-subtracted)
if ~isempty(ac_main)
    results.Action_Main = extract_amplitudes(ac_main, roi_chans, N1_window, P2_window);
    fprintf('  Action Main (motor-subtracted): %d epochs\n', ac_main.trials);
end

%% Create summary table
fprintf('\n--- Creating summary table ---\n');
summary_table = create_summary_table(results, Sub);

% Save to CSV
csv_file = fullfile(out_path, [Sub '_N1_P2_amplitude_comparison.csv']);
writetable(summary_table, csv_file);
fprintf('  Saved: %s\n', csv_file);

% Display table
disp(summary_table);

%% Plot comparisons
fprintf('\n--- Creating comparison plots ---\n');

% 1. NoAction: Adaptation vs Main
if isfield(results, 'NoAction_Adaptation') && isfield(results, 'NoAction_Main')
    plot_amplitude_comparison(...
        results.NoAction_Adaptation, results.NoAction_Main, ...
        'NoAction', 'Adaptation', 'Main', ...
        Sub, fig_path);
end

% 2. Action: Adaptation vs Main (motor-subtracted)
if isfield(results, 'Action_Adaptation') && isfield(results, 'Action_Main')
    plot_amplitude_comparison(...
        results.Action_Adaptation, results.Action_Main, ...
        'Action (motor-subtracted)', 'Adaptation', 'Main', ...
        Sub, fig_path);
end

% 3. Combined comparison plot
if all(isfield(results, {'NoAction_Adaptation', 'NoAction_Main', ...
                        'Action_Adaptation', 'Action_Main'}))
    plot_combined_comparison(results, Sub, fig_path);
end

%% Statistical comparisons
fprintf('\n--- Statistical Comparisons ---\n');
perform_statistics(results, Sub, out_path);

fprintf('\n========================================\n');
fprintf('=== COMPARISON COMPLETE: %s ===\n', Sub);
fprintf('========================================\n\n');

end % main function


%% =========================================================================
%% HELPER: Load EEG dataset
%% =========================================================================
function EEG = load_set(path, filename)
    full_path = fullfile(path, filename);
    if exist(full_path, 'file')
        EEG = pop_loadset('filename', filename, 'filepath', path);
        fprintf('  Loaded: %s (%d epochs)\n', filename, EEG.trials);
    else
        fprintf('  Not found: %s\n', filename);
        EEG = [];
    end
end


%% =========================================================================
%% HELPER: Extract N1 and P2 amplitudes
%% =========================================================================
function amp = extract_amplitudes(EEG, roi_chans, N1_window, P2_window)
    
    % Get channel indices
    if isstruct(EEG.chanlocs)
        chan_labels = {EEG.chanlocs.labels};
    else
        chan_labels = EEG.chanlocs;
    end
    
    roi_idx = [];
    for ch = 1:length(roi_chans)
        idx = find(strcmp(chan_labels, roi_chans{ch}));
        if ~isempty(idx)
            roi_idx(end+1) = idx(1); %#ok<AGROW>
        end
    end
    
    if isempty(roi_idx)
        error('No ROI channels found');
    end
    
    % Get time indices
    times = EEG.times;
    N1_idx = find(times >= N1_window(1) & times <= N1_window(2));
    P2_idx = find(times >= P2_window(1) & times <= P2_window(2));
    
    % Average across ROI channels and epochs
    erp_roi = squeeze(mean(mean(EEG.data(roi_idx, :, :), 3), 1));
    
    % N1: Find most negative peak
    N1_segment = erp_roi(N1_idx);
    [N1_peak_amp, N1_peak_idx] = min(N1_segment);
    N1_peak_lat = times(N1_idx(N1_peak_idx));
    N1_mean_amp = mean(N1_segment);
    
    % P2: Find most positive peak
    P2_segment = erp_roi(P2_idx);
    [P2_peak_amp, P2_peak_idx] = max(P2_segment);
    P2_peak_lat = times(P2_idx(P2_peak_idx));
    P2_mean_amp = mean(P2_segment);
    
    % Store results
    amp.N1_peak_amp = N1_peak_amp;
    amp.N1_peak_lat = N1_peak_lat;
    amp.N1_mean_amp = N1_mean_amp;
    amp.P2_peak_amp = P2_peak_amp;
    amp.P2_peak_lat = P2_peak_lat;
    amp.P2_mean_amp = P2_mean_amp;
    amp.n_epochs = EEG.trials;
    amp.roi_channels = chan_labels(roi_idx);
end


%% =========================================================================
%% HELPER: Create summary table
%% =========================================================================
function tbl = create_summary_table(results, Sub)
    
    conditions = {};
    blocks = {};
    N1_peak = [];
    N1_peak_lat = [];
    N1_mean = [];
    P2_peak = [];
    P2_peak_lat = [];
    P2_mean = [];
    n_epochs = [];
    
    fields = fieldnames(results);
    for f = 1:length(fields)
        field_name = fields{f};
        parts = strsplit(field_name, '_');
        
        if length(parts) >= 2
            condition = parts{1};
            block = parts{2};
        else
            continue;
        end
        
        r = results.(field_name);
        
        conditions{end+1} = condition; %#ok<AGROW>
        blocks{end+1} = block; %#ok<AGROW>
        N1_peak(end+1) = r.N1_peak_amp; %#ok<AGROW>
        N1_peak_lat(end+1) = r.N1_peak_lat; %#ok<AGROW>
        N1_mean(end+1) = r.N1_mean_amp; %#ok<AGROW>
        P2_peak(end+1) = r.P2_peak_amp; %#ok<AGROW>
        P2_peak_lat(end+1) = r.P2_peak_lat; %#ok<AGROW>
        P2_mean(end+1) = r.P2_mean_amp; %#ok<AGROW>
        n_epochs(end+1) = r.n_epochs; %#ok<AGROW>
    end
    
    tbl = table(conditions', blocks', N1_peak', N1_peak_lat', N1_mean', ...
                P2_peak', P2_peak_lat', P2_mean', n_epochs', ...
                'VariableNames', {'Condition', 'Block', 'N1_Peak_uV', 'N1_Peak_Lat_ms', 'N1_Mean_uV', ...
                                  'P2_Peak_uV', 'P2_Peak_Lat_ms', 'P2_Mean_uV', 'N_Epochs'});
end


%% =========================================================================
%% HELPER: Plot amplitude comparison for one condition
%% =========================================================================
function plot_amplitude_comparison(adapt, main, condition_label, adapt_label, main_label, Sub, fig_path)
    
    fig = figure('Position', [100, 100, 1200, 500], 'Visible', 'off');
    
    % Subplot 1: N1 comparison
    subplot(1, 2, 1);
    hold on;
    
    % Peak amplitudes
    bar([1 2], [adapt.N1_peak_amp, main.N1_peak_amp], 'FaceColor', [0.3 0.5 0.8]);
    
    % Mean amplitudes (overlay as scatter)
    scatter([1 2], [adapt.N1_mean_amp, main.N1_mean_amp], 80, 'r', 'filled', 'MarkerEdgeColor', 'k');
    
    set(gca, 'XTick', [1 2], 'XTickLabel', {adapt_label, main_label});
    ylabel('Amplitude (µV)');
    title(sprintf('N1 Amplitude - %s', condition_label));
    legend({'Peak', 'Mean'}, 'Location', 'best');
    grid on;
    
    % Add values as text
    text(1, adapt.N1_peak_amp, sprintf('%.2f', adapt.N1_peak_amp), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    text(2, main.N1_peak_amp, sprintf('%.2f', main.N1_peak_amp), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    
    hold off;
    
    % Subplot 2: P2 comparison
    subplot(1, 2, 2);
    hold on;
    
    % Peak amplitudes
    bar([1 2], [adapt.P2_peak_amp, main.P2_peak_amp], 'FaceColor', [0.8 0.5 0.3]);
    
    % Mean amplitudes (overlay as scatter)
    scatter([1 2], [adapt.P2_mean_amp, main.P2_mean_amp], 80, 'r', 'filled', 'MarkerEdgeColor', 'k');
    
    set(gca, 'XTick', [1 2], 'XTickLabel', {adapt_label, main_label});
    ylabel('Amplitude (µV)');
    title(sprintf('P2 Amplitude - %s', condition_label));
    legend({'Peak', 'Mean'}, 'Location', 'best');
    grid on;
    
    % Add values as text
    text(1, adapt.P2_peak_amp, sprintf('%.2f', adapt.P2_peak_amp), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    text(2, main.P2_peak_amp, sprintf('%.2f', main.P2_peak_amp), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    
    hold off;
    
    % Overall title
    sgtitle(sprintf('%s - %s: Adaptation vs Main Blocks', Sub, condition_label), 'FontSize', 14);
    
    % Save
    safe_label = strrep(condition_label, ' ', '_');
    filename = fullfile(fig_path, sprintf('%s_%s_amplitude_comparison.png', Sub, safe_label));
    saveas(fig, filename);
    close(fig);
    
    fprintf('  Saved: %s\n', filename);
end


%% =========================================================================
%% HELPER: Plot combined comparison across all conditions
%% =========================================================================
function plot_combined_comparison(results, Sub, fig_path)
    
    fig = figure('Position', [100, 100, 1400, 600], 'Visible', 'off');
    
    % Extract data
    na_adapt = results.NoAction_Adaptation;
    na_main = results.NoAction_Main;
    ac_adapt = results.Action_Adaptation;
    ac_main = results.Action_Main;
    
    % Subplot 1: N1 Peak Amplitudes
    subplot(2, 2, 1);
    hold on;
    x = [1 2; 4 5];
    y_n1_peak = [na_adapt.N1_peak_amp, na_main.N1_peak_amp; ...
                 ac_adapt.N1_peak_amp, ac_main.N1_peak_amp];
    bar(x', y_n1_peak', 'grouped');
    set(gca, 'XTick', [1.5 4.5], 'XTickLabel', {'NoAction', 'Action (motor-sub)'});
    ylabel('N1 Peak Amplitude (µV)');
    title('N1 Peak Amplitude');
    legend({'Adaptation', 'Main'}, 'Location', 'best');
    grid on;
    hold off;
    
    % Subplot 2: N1 Mean Amplitudes
    subplot(2, 2, 2);
    hold on;
    y_n1_mean = [na_adapt.N1_mean_amp, na_main.N1_mean_amp; ...
                 ac_adapt.N1_mean_amp, ac_main.N1_mean_amp];
    bar(x', y_n1_mean', 'grouped');
    set(gca, 'XTick', [1.5 4.5], 'XTickLabel', {'NoAction', 'Action (motor-sub)'});
    ylabel('N1 Mean Amplitude (µV)');
    title('N1 Mean Amplitude');
    legend({'Adaptation', 'Main'}, 'Location', 'best');
    grid on;
    hold off;
    
    % Subplot 3: P2 Peak Amplitudes
    subplot(2, 2, 3);
    hold on;
    y_p2_peak = [na_adapt.P2_peak_amp, na_main.P2_peak_amp; ...
                 ac_adapt.P2_peak_amp, ac_main.P2_peak_amp];
    bar(x', y_p2_peak', 'grouped');
    set(gca, 'XTick', [1.5 4.5], 'XTickLabel', {'NoAction', 'Action (motor-sub)'});
    ylabel('P2 Peak Amplitude (µV)');
    title('P2 Peak Amplitude');
    legend({'Adaptation', 'Main'}, 'Location', 'best');
    grid on;
    hold off;
    
    % Subplot 4: P2 Mean Amplitudes
    subplot(2, 2, 4);
    hold on;
    y_p2_mean = [na_adapt.P2_mean_amp, na_main.P2_mean_amp; ...
                 ac_adapt.P2_mean_amp, ac_main.P2_mean_amp];
    bar(x', y_p2_mean', 'grouped');
    set(gca, 'XTick', [1.5 4.5], 'XTickLabel', {'NoAction', 'Action (motor-sub)'});
    ylabel('P2 Mean Amplitude (µV)');
    title('P2 Mean Amplitude');
    legend({'Adaptation', 'Main'}, 'Location', 'best');
    grid on;
    hold off;
    
    % Overall title
    sgtitle(sprintf('%s - N1 and P2 Amplitude Comparison Across Conditions and Blocks', Sub), ...
        'FontSize', 14);
    
    % Save
    filename = fullfile(fig_path, sprintf('%s_combined_amplitude_comparison.png', Sub));
    saveas(fig, filename);
    close(fig);
    
    fprintf('  Saved: %s\n', filename);
end


%% =========================================================================
%% HELPER: Perform statistical comparisons
%% =========================================================================
function perform_statistics(results, Sub, out_path)
    
    stats = struct();
    
    % NoAction: Adaptation vs Main
    if isfield(results, 'NoAction_Adaptation') && isfield(results, 'NoAction_Main')
        fprintf('\n  NoAction: Adaptation vs Main\n');
        
        na_adapt = results.NoAction_Adaptation;
        na_main = results.NoAction_Main;
        
        % N1
        n1_diff_peak = na_adapt.N1_peak_amp - na_main.N1_peak_amp;
        n1_diff_mean = na_adapt.N1_mean_amp - na_main.N1_mean_amp;
        fprintf('    N1 Peak: Adapt=%.2f, Main=%.2f, Diff=%.2f µV\n', ...
            na_adapt.N1_peak_amp, na_main.N1_peak_amp, n1_diff_peak);
        fprintf('    N1 Mean: Adapt=%.2f, Main=%.2f, Diff=%.2f µV\n', ...
            na_adapt.N1_mean_amp, na_main.N1_mean_amp, n1_diff_mean);
        
        % P2
        p2_diff_peak = na_adapt.P2_peak_amp - na_main.P2_peak_amp;
        p2_diff_mean = na_adapt.P2_mean_amp - na_main.P2_mean_amp;
        fprintf('    P2 Peak: Adapt=%.2f, Main=%.2f, Diff=%.2f µV\n', ...
            na_adapt.P2_peak_amp, na_main.P2_peak_amp, p2_diff_peak);
        fprintf('    P2 Mean: Adapt=%.2f, Main=%.2f, Diff=%.2f µV\n', ...
            na_adapt.P2_mean_amp, na_main.P2_mean_amp, p2_diff_mean);
        
        stats.NoAction.N1_peak_diff = n1_diff_peak;
        stats.NoAction.N1_mean_diff = n1_diff_mean;
        stats.NoAction.P2_peak_diff = p2_diff_peak;
        stats.NoAction.P2_mean_diff = p2_diff_mean;
    end
    
    % Action: Adaptation vs Main (motor-subtracted)
    if isfield(results, 'Action_Adaptation') && isfield(results, 'Action_Main')
        fprintf('\n  Action (motor-subtracted): Adaptation vs Main\n');
        
        ac_adapt = results.Action_Adaptation;
        ac_main = results.Action_Main;
        
        % N1
        n1_diff_peak = ac_adapt.N1_peak_amp - ac_main.N1_peak_amp;
        n1_diff_mean = ac_adapt.N1_mean_amp - ac_main.N1_mean_amp;
        fprintf('    N1 Peak: Adapt=%.2f, Main=%.2f, Diff=%.2f µV\n', ...
            ac_adapt.N1_peak_amp, ac_main.N1_peak_amp, n1_diff_peak);
        fprintf('    N1 Mean: Adapt=%.2f, Main=%.2f, Diff=%.2f µV\n', ...
            ac_adapt.N1_mean_amp, ac_main.N1_mean_amp, n1_diff_mean);
        
        % P2
        p2_diff_peak = ac_adapt.P2_peak_amp - ac_main.P2_peak_amp;
        p2_diff_mean = ac_adapt.P2_mean_amp - ac_main.P2_mean_amp;
        fprintf('    P2 Peak: Adapt=%.2f, Main=%.2f, Diff=%.2f µV\n', ...
            ac_adapt.P2_peak_amp, ac_main.P2_peak_amp, p2_diff_peak);
        fprintf('    P2 Mean: Adapt=%.2f, Main=%.2f, Diff=%.2f µV\n', ...
            ac_adapt.P2_mean_amp, ac_main.P2_mean_amp, p2_diff_mean);
        
        stats.Action.N1_peak_diff = n1_diff_peak;
        stats.Action.N1_mean_diff = n1_diff_mean;
        stats.Action.P2_peak_diff = p2_diff_peak;
        stats.Action.P2_mean_diff = p2_diff_mean;
    end
    
    % Save statistics
    save(fullfile(out_path, [Sub '_amplitude_statistics.mat']), 'stats');
    fprintf('\n  Saved: %s_amplitude_statistics.mat\n', Sub);
    
    fprintf('\n  NOTE: For group-level statistics (t-tests), run this across all subjects\n');
    fprintf('        and use paired t-tests on the difference scores.\n');
end