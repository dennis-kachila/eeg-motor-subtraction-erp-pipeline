function results = compute_N1_P2(EEG_adapt, EEG_main, tone_type)
% Compute P50, N1 and P2 ERP components for adaptation and main blocks
%
% Inputs:
%   EEG_adapt  - EEGLAB structure for adaptation block
%   EEG_main   - EEGLAB structure for main block
%   tone_type  - string label (e.g. 'NoAction', 'Action')
%
% Outputs:
%   results    - struct with Adaptation and Main fields, each containing:
%                - per-electrode-group: P50/N1/P2 peak amp, peak lat, mean amp
%                - PerTone.Low / .Med / .High: same metrics for frontal+central
%                  combined, computed separately per tone type

results = struct();

% ------------------------------------------------------------------
% ------------------------------------------------------------------
% Electrode groups (for per-group results, used by topo reference)
% ------------------------------------------------------------------
elec_groups.Fz      = {'Fz'};
elec_groups.FCz     = {'FCz'};
elec_groups.Cz      = {'Cz'};
elec_groups.C3      = {'C3'};
elec_groups.CPz     = {'CPz'};
elec_groups.Frontal = {'Fz','F1','F2','FCz','FC1','FC2'};
elec_groups.Central = {'Cz','C1','C2','C3','CPz'};

% Data-driven ROI: top electrodes by N1 amplitude (ranked from NoAction+Action combined)
% FC1, FC2, FC3, FC4, Fz, F1, F2, Cz, C1, C2, C3, CPz, FCz
all_elecs = {'FCz','FC1','FC2','FC3','FC4','Fz','F1','F2','Cz','C1','C2','C3','CPz'};

% CHANGE 1: Extended time windows to cover P50 and wider N1/P2
P50_window = [30  80];
N1_window  = [80  150];
P2_window  = [150 275];

%% Adaptation block
fprintf('Processing adaptation block for %s...\n', tone_type);
if ~isempty(EEG_adapt) && ~isempty(EEG_adapt.data)
    results.Adaptation          = process_block(EEG_adapt, elec_groups, all_elecs, P50_window, N1_window, P2_window);
    results.Adaptation.n_epochs = EEG_adapt.trials;
else
    fprintf('  Warning: No adaptation data for %s\n', tone_type);
    results.Adaptation = [];
end

%% Main block
fprintf('Processing main block for %s...\n', tone_type);
if ~isempty(EEG_main) && ~isempty(EEG_main.data)
    results.Main          = process_block(EEG_main, elec_groups, all_elecs, P50_window, N1_window, P2_window);
    results.Main.n_epochs = EEG_main.trials;
else
    fprintf('  Warning: No main data for %s\n', tone_type);
    results.Main = [];
end
end


% ------------------------------------------------------------------
function blk = process_block(EEG, elec_groups, all_elecs, P50_window, N1_window, P2_window)

times   = EEG.times;
P50_idx = find(times >= P50_window(1) & times <= P50_window(2));
N1_idx  = find(times >= N1_window(1)  & times <= N1_window(2));
P2_idx  = find(times >= P2_window(1)  & times <= P2_window(2));

if isstruct(EEG.chanlocs) && isfield(EEG.chanlocs, 'labels')
    chan_labels = {EEG.chanlocs.labels};
elseif iscell(EEG.chanlocs)
    chan_labels = EEG.chanlocs;
else
    error('Cannot extract channel labels from EEG.chanlocs');
end

blk = struct();

% ------ Per electrode group (all tones averaged together) ------
group_names = fieldnames(elec_groups);
for g = 1:length(group_names)
    gname      = group_names{g};
    electrodes = elec_groups.(gname);
    chan_idx   = get_chan_idx_local(chan_labels, electrodes);

    if isempty(chan_idx)
        fprintf('  Warning: no channels found for group %s\n', gname);
        continue;
    end

    erp = squeeze(mean(mean(EEG.data(chan_idx, :, :), 3), 1));
    blk.(gname) = compute_peaks(erp, times, P50_idx, N1_idx, P2_idx);
    blk.(gname).erp      = erp;
    blk.(gname).times    = times;
    blk.(gname).chan_idx = chan_idx;
end

% CHANGE 2: Add PerTone field — N1/P2/P50 computed separately per tone
% using combined frontal+central electrodes
tone_types  = {'Tone_Low', 'Tone_Med', 'Tone_High'};
tone_fields = {'Low',      'Med',      'High'};
all_idx     = get_chan_idx_local(chan_labels, all_elecs);

blk.PerTone = struct();
for t = 1:length(tone_types)
    epoch_idx = get_tone_epochs(EEG, tone_types{t});
    if ~any(epoch_idx) || isempty(all_idx)
        blk.PerTone.(tone_fields{t}) = empty_peaks();
        continue;
    end
    erp = squeeze(mean(mean(EEG.data(all_idx, :, epoch_idx), 3), 1));
    blk.PerTone.(tone_fields{t})          = compute_peaks(erp, times, P50_idx, N1_idx, P2_idx);
    blk.PerTone.(tone_fields{t}).n_epochs = sum(epoch_idx);
    blk.PerTone.(tone_fields{t}).erp      = erp;
end
end


% ------------------------------------------------------------------
function pk = compute_peaks(erp, times, P50_idx, N1_idx, P2_idx)
    % Tie-aware extrema + sub-sample interpolation reduce quantization
    % artifacts where many latencies can collapse to the same sample.
    P50_seg = erp(P50_idx);
    [P50_amp, P50_lat] = robust_peak_latency(P50_seg, times(P50_idx), +1);

    N1_seg = erp(N1_idx);
    [N1_peak_amp, N1_peak_lat] = robust_peak_latency(N1_seg, times(N1_idx), -1);
    N1_mean_amp = mean(N1_seg);

    P2_seg = erp(P2_idx);
    [P2_peak_amp, P2_peak_lat] = robust_peak_latency(P2_seg, times(P2_idx), +1);
    P2_mean_amp = mean(P2_seg);

    pk.P50_peak_amp = P50_amp;
    pk.P50_peak_lat = P50_lat;
    pk.N1_peak_amp  = N1_peak_amp;
    pk.N1_peak_lat  = N1_peak_lat;
    pk.N1_mean_amp  = N1_mean_amp;
    pk.P2_peak_amp  = P2_peak_amp;
    pk.P2_peak_lat  = P2_peak_lat;
    pk.P2_mean_amp  = P2_mean_amp;
end

function [peak_amp, peak_lat] = robust_peak_latency(seg, seg_times, polarity)
    seg = double(seg(:)');
    seg_times = double(seg_times(:)');

    if isempty(seg)
        peak_amp = NaN;
        peak_lat = NaN;
        return;
    end

    smooth_seg = movmean(seg, min(5, numel(seg)));
    if polarity > 0
        target_val = max(smooth_seg);
    else
        target_val = min(smooth_seg);
    end

    tol = max(1e-9, 1e-6 * max(1, range(smooth_seg)));
    cand = find(abs(smooth_seg - target_val) <= tol);
    if isempty(cand)
        [~, idx] = min(abs(smooth_seg - target_val));
    else
        idx = round(mean(cand));
    end

    peak_amp = seg(idx);
    peak_lat = seg_times(idx);

    % Quadratic interpolation around the extremum for sub-sample latency.
    if idx > 1 && idx < numel(seg)
        y1 = seg(idx - 1);
        y2 = seg(idx);
        y3 = seg(idx + 1);
        denom = (y1 - 2*y2 + y3);
        if abs(denom) > 1e-12
            delta = 0.5 * (y1 - y3) / denom;
            if abs(delta) <= 1
                dt = seg_times(2) - seg_times(1);
                peak_lat = peak_lat + delta * dt;
                peak_amp = y2 - 0.25 * (y1 - y3) * delta;
            end
        end
    end
end


function pk = empty_peaks()
    pk.P50_peak_amp = NaN; pk.P50_peak_lat = NaN;
    pk.N1_peak_amp  = NaN; pk.N1_peak_lat  = NaN;
    pk.N1_mean_amp  = NaN;
    pk.P2_peak_amp  = NaN; pk.P2_peak_lat  = NaN;
    pk.P2_mean_amp  = NaN;
    pk.n_epochs     = 0;   pk.erp          = [];
end


function chan_idx = get_chan_idx_local(chan_labels, electrodes)
    chan_idx = [];
    for e = 1:length(electrodes)
        idx = find(strcmp(chan_labels, electrodes{e}));
        if ~isempty(idx), chan_idx = [chan_idx idx(1)]; end
    end
end


function epoch_idx = get_tone_epochs(EEG, tone_type)
    epoch_idx = false(1, EEG.trials);
    for ep = 1:EEG.trials
        ev = EEG.epoch(ep).eventtype;
        if ~iscell(ev)
            ev = {ev};
        end

        for k = 1:numel(ev)
            ek = ev{k};
            if ischar(ek) || isstring(ek)
                if strcmp(char(ek), tone_type) || contains(char(ek), tone_type)
                    epoch_idx(ep) = true;
                    break;
                end
            elseif isnumeric(ek)
                if (strcmp(tone_type, 'Tone_Low')  && ek == 61) || ...
                   (strcmp(tone_type, 'Tone_Med')  && ek == 62) || ...
                   (strcmp(tone_type, 'Tone_High') && ek == 63)
                    epoch_idx(ep) = true;
                    break;
                end
            end
        end
    end
end