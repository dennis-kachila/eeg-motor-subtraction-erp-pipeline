function [EEG] = ApplyFilters(EEG, cfg)
% Apply high-pass and low-pass filters to EEG data
%
% Inputs:
%   EEG - EEGLAB EEG structure
%   cfg - configuration structure with filter parameters
%
% Outputs:
%   EEG - filtered EEG structure

% low pass filter
if cfg.runFilter_LP == 1
    fprintf('Applying low-pass filter at %.1f Hz...\n', cfg.lp_filter_limit);
    [m, ~] = pop_firwsord('blackman', EEG.srate, cfg.lp_filter_tbandwidth);
    max_fir_order = 30000;
    if m > max_fir_order
        warning('ApplyFilters:LPFilterOrderCapped', ...
            'Low-pass FIR order %d exceeds cap %d. Capping for stability.', m, max_fir_order);
        m = max_fir_order;
    end
    [EEG, com] = pop_firws(EEG, 'fcutoff', cfg.lp_filter_limit, 'ftype',...
                                'lowpass', 'wtype', 'blackman', 'forder', m, 'usefftfilt', 1);
    EEG = eegh(com, EEG);
end

% high pass filter
if cfg.runFilter_HP == 1
    fprintf('Applying high-pass filter at %.2f Hz...\n', cfg.hp_filter_limit);
    [m, ~] = pop_firwsord('hamming', EEG.srate, cfg.hp_filter_tbandwidth);
    max_fir_order = 30000;
    if m > max_fir_order
        warning('ApplyFilters:HPFilterOrderCapped', ...
            'High-pass FIR order %d exceeds cap %d. Capping for stability.', m, max_fir_order);
        m = max_fir_order;
    end
    [EEG, com] = pop_firws(EEG, 'fcutoff', cfg.hp_filter_limit, 'ftype',...
                                'highpass', 'wtype', 'hamming', 'forder', m, 'usefftfilt', 1);
    EEG = eegh(com, EEG);
end
