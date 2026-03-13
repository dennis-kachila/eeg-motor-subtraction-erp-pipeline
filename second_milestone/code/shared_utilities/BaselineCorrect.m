function [EEG] = BaselineCorrect(EEG, cfg)

if cfg.runBaselineCorrect == 1
    if abs(cfg.StartBsl) < 30    
        [EEG, com] =  pop_rmbase( EEG, [cfg.StartBsl*1000  cfg.EndBsl*1000]);
    else
        [EEG, com] = pop_rmbase( EEG, [cfg.StartBsl cfg.EndBsl]);
    end
    EEG = eegh(com, EEG);
end