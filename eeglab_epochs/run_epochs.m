%% Run Extract Conditions (Step 6)
% Epoch data and separate into adaptation and main blocks


clear all; close all; clc;

% OPTION 1: Process just sub-01
subjects = {'sub-01'};

% OPTION 2: Process ALL subjects (1-13)
% subjects = {'sub-01', 'sub-02', 'sub-03', 'sub-04', 'sub-05', 'sub-06', ...
%             'sub-07', 'sub-08', 'sub-09', 'sub-10', 'sub-11', 'sub-12', 'sub-13'};

% Run condition extraction
RunMyScripts('Subs', subjects, 'Script', 'PrepareData', 'Function', 6, 'Pipeline', 1);