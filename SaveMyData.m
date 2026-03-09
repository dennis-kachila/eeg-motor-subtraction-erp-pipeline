function SaveMyData(EEG, filename, outPath)
% Minimal save helper compatible with existing pipeline calls.

if ~exist(outPath, 'dir')
    mkdir(outPath);
end

pop_saveset(EEG, 'filename', filename, 'filepath', outPath);
end
