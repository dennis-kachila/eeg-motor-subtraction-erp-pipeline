function plot_grand_average_waveforms(EEG, base_name, block_name, output_path)
% Plot grand average waveforms separated by tone type
%
% Inputs:
%   EEG         - EEGLAB structure with epoched data
%   base_name   - Base filename for saving
%   block_name  - 'Adaptation' or 'Main'
%   output_path - Directory to save figure

% Data-driven ROI electrodes (ranked by N1 amplitude, NoAction+Action combined)
roi_elecs = {'FCz','FC1','FC2','FC3','FC4','Fz','F1','F2','Cz','C1','C2','C3','CPz'};

chan_idx = [];
for i = 1:length(roi_elecs)
    idx = find(strcmp({EEG.chanlocs.labels}, roi_elecs{i}));
    if ~isempty(idx)
        chan_idx = [chan_idx idx];
    end
end
if isempty(chan_idx)
    fprintf('    Warning: ROI electrodes not found for plotting\n');
    return;
end

% Tone types
tone_types  = {'Tone_Low', 'Tone_Med', 'Tone_High'};
tone_colors = {[0 0 0.85], [0 0.65 0], [0.85 0 0]};
tone_labels = {'Low', 'Medium', 'High'};

% Create figure
fig = figure('Position', [100 100 950 620], 'Visible', 'off');
hold on;

for t = 1:length(tone_types)
    tone_epochs = [];
    for ep = 1:EEG.trials
        ep_event_idx = find([EEG.event.epoch] == ep);
        if ~isempty(ep_event_idx)
            for ev = ep_event_idx
                if strcmp(EEG.event(ev).type, tone_types{t})
                    tone_epochs = [tone_epochs ep];
                    break;
                end
            end
        end
    end

    if isempty(tone_epochs)
        fprintf('    Warning: No epochs found for %s\n', tone_types{t});
        continue;
    end

    tone_avg = squeeze(mean(mean(EEG.data(chan_idx, :, tone_epochs), 3), 1));
    plot(EEG.times, tone_avg, 'Color', tone_colors{t}, 'LineWidth', 2, ...
        'DisplayName', tone_labels{t});
    fprintf('    Plotted %s: %d epochs\n', tone_labels{t}, length(tone_epochs));
end

% Shaded N1 and P2 windows
yl = [-10 10];
ylim(yl);
fill([80 150 150 80],   [yl(1) yl(1) yl(2) yl(2)], [0.55 0.55 0.55], ...
    'FaceAlpha', 0.13, 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([150 275 275 150], [yl(1) yl(1) yl(2) yl(2)], [0.45 0.45 1.0], ...
    'FaceAlpha', 0.13, 'EdgeColor', 'none', 'HandleVisibility', 'off');

xline(0,   'r--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
xline(80,  '-',   'Color', [0.4 0.4 0.4], 'LineWidth', 1.0, 'HandleVisibility', 'off');
xline(150, '-',   'Color', [0.3 0.3 0.8], 'LineWidth', 1.0, 'HandleVisibility', 'off');

text(115,  yl(2)-0.3, 'N1', 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', [0.4 0.4 0.4]);
text(212,  yl(2)-0.3, 'P2', 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', [0.3 0.3 0.8]);

set(gca, 'YDir', 'reverse');
xlabel('Time (ms)', 'FontSize', 12);
ylabel('Amplitude (\muV)', 'FontSize', 12);
title(sprintf('Grand Average - ROI Electrodes (%s Block)', block_name), 'FontSize', 13);
legend('Location', 'southeast', 'FontSize', 10);
xlim([-100 500]);
grid on;
hold off;

filename = [output_path base_name '_' block_name '_grand_average.png'];
saveas(fig, filename);
close(fig);
fprintf('    Saved: %s_%s_grand_average.png\n', base_name, block_name);
end