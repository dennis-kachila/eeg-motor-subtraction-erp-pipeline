function [EEG] = Rereference(EEG, cfg)

if cfg.runReref == 1
   if isempty(cfg.Reference{1}) == 1
      [EEG, com] = pop_reref( EEG, cfg.Reference{1}, 'keepref','on');
      EEG = eegh(com, EEG); 
   else
      [WhichRef] = GetChannelIndices(EEG.chanlocs, cfg.Reference);
      [EEG,com] = pop_reref( EEG, WhichRef, 'keepref','on');
      EEG = eegh(com, EEG);
   end
end