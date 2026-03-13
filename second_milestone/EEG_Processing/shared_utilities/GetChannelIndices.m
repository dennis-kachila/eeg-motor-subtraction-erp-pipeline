% takes chanlocs structure from the EEGLAB EEG struct and a cell array with
% electrode names and hands back indices of these electrodes

function [WhichRef] = GetChannelIndices(chanlocs, mychans)

WhichRef = [];
if isempty(mychans)== 0
for c = 1:length(chanlocs)
  for b = 1:length(mychans)
      if strcmp(chanlocs(c).labels,mychans{b}) == 1
         WhichRef = [WhichRef c];
      end
  end
end 

if length(WhichRef) ~= length(mychans)
   error('Please check the electrode names you were using as input. Seems like not all of them are present in EEG struct.'); 
end
end