function plot_scalp_topographies(EEG, results, base_name, block_name, output_path)

if isempty(results) || ~isfield(results, 'Central')
    fprintf('    Warning: No results for topography plotting\n');
    return;
end

N1_lat = results.Central.N1_lat;
P2_lat = results.Central.P2_lat;

times  = EEG.times;
N1_idx = find(times >= N1_lat, 1, 'first');
P2_idx = find(times >= P2_lat, 1, 'first');

n_scalp_chans = min(64, EEG.nbchan);
N1_topo = mean(EEG.data(1:n_scalp_chans, N1_idx, :), 3);
P2_topo = mean(EEG.data(1:n_scalp_chans, P2_idx, :), 3);

topo_clim = [-10 10];   % fixed colour scale for comparability

fig = figure('Position', [100, 100, 1200, 500], 'Visible', 'off');

subplot(1, 2, 1);
topoplot(N1_topo, EEG.chanlocs(1:n_scalp_chans), 'electrodes', 'on', 'style', 'map');
title(sprintf('N1 Topography (%.0f ms) - %s', N1_lat, block_name), 'FontSize', 12);
clim(topo_clim);   % use caxis(topo_clim) if MATLAB < R2022a
colorbar;

subplot(1, 2, 2);
topoplot(P2_topo, EEG.chanlocs(1:n_scalp_chans), 'electrodes', 'on', 'style', 'map');
title(sprintf('P2 Topography (%.0f ms) - %s', P2_lat, block_name), 'FontSize', 12);
clim(topo_clim);   % use caxis(topo_clim) if MATLAB < R2022a
colorbar;

sgtitle(sprintf('%s  |  %s', base_name, block_name), 'FontSize', 13);

filename = [output_path base_name '_' block_name '_topography.png'];
saveas(fig, filename);
close(fig);
end