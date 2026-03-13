function EEG = label_events(EEG)
% Label EEG events with descriptive names
% Handles both numeric codes and "condition XX" format from BDF files

unknown_numeric_codes = [];
unknown_string_types = {};

for i = 1:length(EEG.event)
    event_type = EEG.event(i).type;
    
    % Convert "condition XX" strings to numbers
    if isstring(event_type)
        event_type = char(event_type);
    end

    if ischar(event_type) && ~isempty(regexpi(event_type, 'condition'))
        % Extract number from variants like "condition 61" or "Condition:61"
        tokens = regexpi(event_type, 'condition\s*[:_-]?\s*(\d+)', 'tokens', 'once');
        if ~isempty(tokens)
            event_type = str2double(tokens{1});
        end
    elseif ischar(event_type)
        % Try to convert string to number
        converted_type = str2double(strtrim(event_type));
        if ~isnan(converted_type)
            event_type = converted_type;
        end
    end
    
    % Label based on event code
    switch event_type
        % Experiment markers
        case 254
            EEG.event(i).type = 'Experiment_Start';
        case 255
            EEG.event(i).type = 'Experiment_End';
            
        % Block markers
        case 10
            EEG.event(i).type = 'Baseline_Block';
        case 11
            EEG.event(i).type = 'Adaptation_Block';
        case 12
            EEG.event(i).type = 'Practice_Block';
        case 13
            EEG.event(i).type = 'Main_Block';
            
        % Trial structure
        case 20
            EEG.event(i).type = 'Trial_Start';
        case 29
            EEG.event(i).type = 'Trial_End';
        case 30
            EEG.event(i).type = 'Fixation_On';
        case 40
            EEG.event(i).type = 'Fixation_Off';
        case 50
            EEG.event(i).type = 'Key_Press';
            
        % Stimuli - THESE ARE YOUR MAIN TONE EVENTS
        case 61
            EEG.event(i).type = 'Tone_Low';
        case 62
            EEG.event(i).type = 'Tone_Med';
        case 63
            EEG.event(i).type = 'Tone_High';
        case 70
            EEG.event(i).type = 'Flash';
            
        % Responses
        case 80
            EEG.event(i).type = 'Response_Prompt';
        case 91
            EEG.event(i).type = 'Resp_Sync';
        case 92
            EEG.event(i).type = 'Resp_Async';
            
        otherwise
            % Keep original if not in list and collect summary diagnostics
            if isnumeric(event_type) && ~isnan(event_type)
                unknown_numeric_codes(end+1) = event_type; %#ok<AGROW>
            elseif ischar(event_type)
                unknown_string_types{end+1} = event_type; %#ok<AGROW>
            end
    end
end

% Summarize unknown/unmapped events once per dataset for easier QA
if ~isempty(unknown_numeric_codes)
    unknown_numeric_codes = unique(unknown_numeric_codes);
    fprintf('Unmapped numeric event codes retained: %s\n', num2str(unknown_numeric_codes));
end

if ~isempty(unknown_string_types)
    unknown_string_types = unique(unknown_string_types);
    fprintf('Unmapped string event types retained: %s\n', strjoin(unknown_string_types, ', '));
end

% Structure validation: check basic fields without calling eeg_checkset
if ~isfield(EEG, 'event') || isempty(EEG.event)
    EEG.event = [];
end

end