%% Run Extract Conditions (Step 6)
% Epoch data and separate into adaptation and main blocks


clear all; close all; clc;

% Ensure shared utilities are available when launching this script directly.
this_script_dir = fileparts(mfilename('fullpath'));
if isempty(this_script_dir)
	this_script_dir = pwd;
end
code_root = fileparts(this_script_dir);
shared_utils_dir = fullfile(code_root, 'shared_utilities');

if exist(shared_utils_dir, 'dir')
	addpath(shared_utils_dir);
else
	error('Shared utilities folder not found: %s', shared_utils_dir);
end

% Keep local epoch helpers resolvable if MATLAB was launched elsewhere.
addpath(this_script_dir);

% OPTION 1: Process just sub-01
subjects = {'sub-01'};

% OPTION 2: Process ALL subjects (1-13)
% subjects = {'sub-01', 'sub-02', 'sub-03', 'sub-04', 'sub-05', 'sub-06', ...
%             'sub-07', 'sub-08', 'sub-09', 'sub-10', 'sub-11', 'sub-12', 'sub-13'};

% Run condition extraction
RunMyScripts('Subs', subjects, 'Script', 'PrepareData', 'Function', 6, 'Pipeline', 1);