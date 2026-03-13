% This function extracts files from a directory given a substring

function outfiles = GetFileBySubstring (Path, subString)

files = dir(Path);  %% find all files in EEG path
outfiles = {files((~cellfun('isempty',strfind({files.name},subString)))).name};