% $$$$$$$$$
% function CreateAndModifyPipelineAsset(Pipeline, Modify)
% $$$$$$$$$
% 
% This file is used to create a pipeline asset containing all the variables
% called by the PrepareData functions. The pipeline will be stored in the
% pipeline folder under its specific index (e.g. "Pipeline_001"). It will
% be stored in the form of a mat file containing all variables in form of a
% struct.
%
% Input parameter: Pipeline - integer between 1 and 999
%                  Modify - 1 = yes, 0 = no
%
% Whenever you ask to modify an existing pipeline the old version will be
% stored in the same folder and changes will be tracked.

function CreateAndModifyPipelineAsset(Pipeline, Modify)

%% Run checks
clc; 

if nargin < 1
   Pipeline = 1; 
   Modify = 0;
elseif nargin < 2
   Modify = 0;
end

if Pipeline < 1 || Pipeline > 999
   error('Provided pipeline index is <1 or >999. Please use only values in range.'); 
end

if Modify ~= 0 && Modify ~= 1 
   error('Modify index has to be 0 or 1. Please change.'); 
end

%% Create a path and load old data if required
cfgPath = GetFilePathsAndInitializeToolboxes;
myPipeline = [cfgPath.PATH.PipelineAsset 'Pipeline_' sprintf('%03d',Pipeline) filesep];

if ~exist(myPipeline, 'dir') && Modify == 1
   error('You want to modify a non-existing pipeline. Please choose another pipeline index.'); 
elseif ~exist(myPipeline, 'dir') && Modify == 0
   mkdir(myPipeline); 
elseif exist(myPipeline, 'dir') && Modify == 0
   error('You wanted to create a pipeline that already exists. Please choose another pipeline index.'); 
elseif exist(myPipeline, 'dir') && Modify == 1
   warning('You are about to alter an existing pipeline!'); disp(' '); disp(' ');
end


%% =========================================================
%% Set Parameters for each preprocessing step
%% =========================================================

% file naming - session number will be auto-detected per subject
cfg.ProcessSourceFiles.EEGsourceFiletype = '.bdf';


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PrepareData_1_Preprocessing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cfg.Preprocessing.FileIn  = '';
cfg.Preprocessing.FileOut = '_preproc';

% Remove dead EOG channels
cfg.Preprocessing.removeDeadChannels  = 1;
cfg.Preprocessing.deadChannelNames    = {'Up Vertical Left', 'Up Vertical Righ', 'Horizontal Right', 'Down Vertical Ri'};

% High-pass filter
cfg.Preprocessing.runFilter_HP        = 1;
cfg.Preprocessing.hp_filter_tbandwidth = 0.05;
cfg.Preprocessing.hp_filter_limit     = 0.1;

% Low-pass filter
cfg.Preprocessing.runFilter_LP        = 1;
cfg.Preprocessing.lp_filter_tbandwidth = 5;
cfg.Preprocessing.lp_filter_limit     = 30;

% Downsample
cfg.Preprocessing.runResample         = 1;
cfg.Preprocessing.SamplingRate        = 256;

% Re-reference to mastoids
cfg.Preprocessing.runReref            = 1;
cfg.Preprocessing.Reference           = {'Mastoid Left', 'Mastoid Right'};

% Detrend
cfg.Preprocessing.runDetrend_BeforeEpoch = 0;
cfg.Preprocessing.runDetrend_AfterEpoch  = 0;

% Epoch (keep off for ICA)
cfg.Preprocessing.runEpoch            = 0;
cfg.Preprocessing.epoch_tmin          = -1;
cfg.Preprocessing.epoch_tmax          = 2;
cfg.Preprocessing.TriggerForEpoch     = {61, 62, 63};

% Baseline correction
cfg.Preprocessing.runBaselineCorrect  = 0;
cfg.Preprocessing.StartBsl            = -0.1;
cfg.Preprocessing.EndBsl              = 0;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PrepareData_2_AutomaticArtifactRejection
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cfg.AutoReject.FileIn  = '_preproc';
cfg.AutoReject.FileOut = '_clean';

% Re-reference before artifact detection (keep off - already done in Step 1)
cfg.AutoReject.runReref            = 0;
cfg.AutoReject.Reference           = {'Mastoid Left', 'Mastoid Right'};

% Baseline correction before artifact detection (keep off for continuous)
cfg.AutoReject.runBaselineCorrect  = 0;
cfg.AutoReject.StartBsl            = -0.1;
cfg.AutoReject.EndBsl              = 0;

% pop_clean_rawdata parameters
cfg.AutoReject.FlatlineCriterion   = 5;
cfg.AutoReject.ChannelCriterion    = 0.8;
cfg.AutoReject.LineNoiseCriterion  = 4;
cfg.AutoReject.BurstCriterion      = 20;
cfg.AutoReject.WindowCriterion     = 0.25;
cfg.AutoReject.BurstRejection      = 'on';
cfg.AutoReject.Distance            = 'Euclidian';


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PrepareData_3_RunICA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cfg.RunICA.FileIn  = '_clean';
cfg.RunICA.FileOut = '_ICA';

% Re-reference before ICA (keep off)
cfg.RunICA.runReref           = 0;
cfg.RunICA.Reference          = {'Mastoid Left', 'Mastoid Right'};

% Baseline correction before ICA (keep off for continuous)
cfg.RunICA.runBaselineCorrect = 0;
cfg.RunICA.StartBsl           = -0.1;
cfg.RunICA.EndBsl             = 0;

% ICA parameters
cfg.RunICA.ica_type           = 'auto_fast';
cfg.RunICA.ica_extended       = 1;
cfg.RunICA.ica_chans          = [];
cfg.RunICA.ica_ncomps         = 55;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PrepareData_4_RejectICs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cfg.RejICA.FileIn  = '_ICA';
cfg.RejICA.FileOut = '_ICrej';

% ICLabel parameters
cfg.RejICA.use_iclabel          = 1;
cfg.RejICA.brain_threshold      = 0.3;
cfg.RejICA.artifact_threshold   = 0.9;
cfg.RejICA.reject_muscle        = 1;
cfg.RejICA.reject_eye           = 1;
cfg.RejICA.reject_heart         = 1;
cfg.RejICA.reject_line_noise    = 1;
cfg.RejICA.reject_channel_noise = 1;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PrepareData_5_PostICAProcessing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cfg.PostICA.FileIn  = '_ICrej';
cfg.PostICA.FileOut = '_post_ICA';

% Epoch rejection (keep off - data is continuous)
cfg.PostICA.runEpochRejection    = 0;
cfg.PostICA.voltage_threshold    = 100;
cfg.PostICA.use_probability      = 1;
cfg.PostICA.probability_threshold = 5;

% Channel interpolation (keep off)
cfg.PostICA.interpolate_channels = 0;

% Final re-reference to mastoids
cfg.PostICA.runReref              = 1;
cfg.PostICA.Reference             = {'Mastoid Left', 'Mastoid Right'};


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PrepareData_6_ExtractConditions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cfg.ExtractConditions.FileIn             = '_post_ICA';

cfg.ExtractConditions.epoch_tmin     = -0.45;   
cfg.ExtractConditions.epoch_tmax     =  0.65;   
cfg.ExtractConditions.baseline_start = -0.45;   
cfg.ExtractConditions.baseline_end   = -0.25;   

% Condition names and event codes
cfg.ExtractConditions.ConditionNames     = {'Tone_Low', 'Tone_Med', 'Tone_High'};
cfg.ExtractConditions.ConditionEvents    = {61, 62, 63};

% Block extraction
cfg.ExtractConditions.extract_adaptation = 1;
cfg.ExtractConditions.extract_main       = 1;
cfg.ExtractConditions.n_adaptation       = 100;   % first N tones = adaptation block

% Motor epoch window (action condition only)
cfg.ExtractConditions.epoch_tmin_motor   = -0.5;
cfg.ExtractConditions.epoch_tmax_motor   = 0.9;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PrepareData_7_ComputeERPs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cfg.ComputeERPs.placeholder = 1;


%% =========================================================
%% Save pipeline asset config file
%% =========================================================

oldfiles = GetFileBySubstring(myPipeline, 'version');

if isempty(oldfiles)
   cfg.ChangeLog = cell2table(cell(0,5), 'VariableNames', ...
       {'VersionChange', 'StructHierachy', 'ChangedVariable', 'ChangeType', 'TimeStamp'});
   save([myPipeline 'Pipeline_' sprintf('%03d',Pipeline) '_version' sprintf('%03d',1) '.mat'], 'cfg');
   fprintf('Created new pipeline %03d, version 001.\n', Pipeline);
else
   ID = GetLastFileIndex(oldfiles);
   cfgOld = load([myPipeline 'Pipeline_' sprintf('%03d',Pipeline) '_version' sprintf('%03d',ID) '.mat']);
   cfgOld = cfgOld.cfg;
   
   cfg.ChangeLog = cfgOld.ChangeLog;
   myChanges = CreateChangelog(cfg, cfgOld, ID);
   cfg.ChangeLog = [cfg.ChangeLog; myChanges];
   
   if isempty(myChanges) || height(myChanges) == 0
       warning('No changes to save ...')
   else
       save([myPipeline 'Pipeline_' sprintf('%03d',Pipeline) '_version' sprintf('%03d',ID+1) '.mat'], 'cfg');
       fprintf('Updated pipeline %03d to version %03d.\n', Pipeline, ID+1);
   end
end

end


%% =========================================================
%% Changelog helpers
%% =========================================================

function myChanges = CreateChangelog(cfg, cfgOld, ID)

    myChanges = {};
    ChangeBetween = [sprintf('%03d',ID) ' to ' sprintf('%03d',ID+1)];

    myVarStr    = 'cfg.';
    myFieldsOld = fieldnames(cfgOld);
    myFields    = fieldnames(cfg);

    myChanges = TrackChangesAdditionRemoval(myChanges, myVarStr, ChangeBetween, setdiff(myFieldsOld, myFields), 'upper', 'removed');
    myChanges = TrackChangesAdditionRemoval(myChanges, myVarStr, ChangeBetween, setdiff(myFields, myFieldsOld), 'upper', 'added');

    myCommonFields = intersect(myFieldsOld, myFields);
    for f = 1:length(myCommonFields)
        if strcmp(myCommonFields{f}, 'ChangeLog'), continue; end

        myVarStr    = ['cfg.' myCommonFields{f} '.'];
        myFieldsOld = fieldnames(cfgOld.(myCommonFields{f}));
        myFields    = fieldnames(cfg.(myCommonFields{f}));

        myChanges = TrackChangesAdditionRemoval(myChanges, myVarStr, ChangeBetween, setdiff(myFieldsOld, myFields), 'lower', 'removed');
        myChanges = TrackChangesAdditionRemoval(myChanges, myVarStr, ChangeBetween, setdiff(myFields, myFieldsOld), 'lower', 'added');

        myCommonFields2 = intersect(myFieldsOld, myFields);
        for f2 = 1:length(myCommonFields2)
            if ~isequal(cfgOld.(myCommonFields{f}).(myCommonFields2{f2}), ...
                        cfg.(myCommonFields{f}).(myCommonFields2{f2}))
                myChanges = [myChanges; {ChangeBetween, myVarStr, myCommonFields2{f2}, 'modified', datestr(now)}]; %#ok<AGROW>
            end
        end
    end

    if isempty(myChanges)
        myChanges = cell2table(cell(0,5), 'VariableNames', ...
            {'VersionChange', 'StructHierachy', 'ChangedVariable', 'ChangeType', 'TimeStamp'});
    else
        myChanges = cell2table(myChanges, 'VariableNames', ...
            {'VersionChange', 'StructHierachy', 'ChangedVariable', 'ChangeType', 'TimeStamp'});
    end
end

function myChanges = TrackChangesAdditionRemoval(myChanges, myVarStr, ChangeBetween, myFields, ~, ChangeType)
    for f = 1:length(myFields)
        myChanges = [myChanges; {ChangeBetween, myVarStr, myFields{f}, ChangeType, datestr(now)}]; %#ok<AGROW>
    end
end