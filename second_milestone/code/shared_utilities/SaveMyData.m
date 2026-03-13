function SaveMyData(EEG, Name, Path)

% Ensure the output directory exists before saving
if ~isempty(Path) && ~exist(Path, 'dir')
    mkdir(Path);
end

[EEG, com] = pop_editset(EEG, 'setname', Name);
EEG = eegh(com, EEG);

[EEG, com] = eeg_checkset( EEG );
EEG = eegh(com, EEG);

[EEG, com] = pop_saveset( EEG, Name, Path);
EEG = eegh(com, EEG);

    