function [EEG] = Rereference(EEG, cfg)

if cfg.runReref == 1
   if isempty(cfg.Reference{1}) == 1
      [EEG, com] = pop_reref(EEG, cfg.Reference{1}, 'keepref', 'on');
      EEG = eegh(com, EEG);
   else
      chan_labels = strtrim({EEG.chanlocs.labels});
      ref_labels = cfg.Reference;
      which_ref = [];
      missing_refs = {};

      for r = 1:numel(ref_labels)
         this_ref = strtrim(ref_labels{r});
         idx = find(strcmpi(chan_labels, this_ref), 1, 'first');
         if ~isempty(idx)
            which_ref(end+1) = idx; %#ok<AGROW>
         else
            missing_refs{end+1} = ref_labels{r}; %#ok<AGROW>
         end
      end

      if isempty(which_ref)
         warning('Rereference:MissingReferenceChannels', ...
             'None of the requested reference channels were found (%s). Skipping re-reference.', ...
             strjoin(ref_labels, ', '));
      else
         if ~isempty(missing_refs)
            warning('Rereference:PartialReferenceChannels', ...
                'Some reference channels were missing (%s). Re-referencing with available channels only (%s).', ...
                strjoin(missing_refs, ', '), strjoin(ref_labels(~ismember(ref_labels, missing_refs)), ', '));
         end
         [EEG, com] = pop_reref(EEG, which_ref, 'keepref', 'on');
         EEG = eegh(com, EEG);
      end
   end
end