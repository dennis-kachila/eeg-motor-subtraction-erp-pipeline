%% Run Extract Conditions (Step 6)
% Epoch data and separate into adaptation and main blocks


clear all; close all; clc;

%% Initialize EEGLAB
eeglab nogui;

%% Add shared utilities to path
% Legacy Linux path (kept for reference):
% addpath('/data/projects/temporal_binding/code/shared_utilities');

% Windows/local path setup - resolve shared_utilities relative to this script
this_script_dir = fileparts(mfilename('fullpath'));
code_root = fileparts(this_script_dir);

shared_utils_candidates = {
	fullfile(code_root, 'shared_utilities'), ...
	fullfile(fileparts(code_root), 'EEG_Processing', 'shared_utilities')
};

for p = 1:numel(shared_utils_candidates)
	if exist(shared_utils_candidates{p}, 'dir')
		addpath(shared_utils_candidates{p});
	end
end

% Pipeline index
pipeline = 3;

% OPTION 1: Process just sub-01
subjects = {'sub-01'};

% OPTION 2: Process ALL subjects (1-13)
% subjects = {'sub-01', 'sub-02', 'sub-03', 'sub-04', 'sub-05', 'sub-06', ...
%             'sub-07', 'sub-08', 'sub-09', 'sub-10', 'sub-11', 'sub-12', 'sub-13'};

% Run condition extraction
RunMyScripts('Subs', subjects, 'Script', 'PrepareData', 'Function', 6, 'Pipeline', pipeline);