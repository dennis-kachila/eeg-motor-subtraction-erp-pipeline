# ERP-Level vs Trial-Level Motor Subtraction Assessment

Date: 2026-03-09

## Question
Should motor-template subtraction be done at ERP level (subtract from the average) or at trial level (subtract from each epoch) for this Action vs No-Action design?

## Conclusion
Trial-level subtraction is more appropriate as the primary approach for this project.

ERP-level subtraction may be kept only as a secondary sensitivity/visualization analysis.

## Rationale

1. Mathematical equivalence for the mean (with a fixed template)
- If the same template is subtracted from all trials:
  - `mean(trial - template) = mean(trial) - template`
- Therefore ERP-level subtraction does not intrinsically improve the mean ERP compared with trial-level subtraction.

2. ERP-level replacement removes physiological trial variability
- In the current ERP-level implementation, one cleaned ERP per tone is replicated into all trials of that tone.
- This creates artificially identical trials and can distort downstream quality checks, variance estimates, and any trialwise analyses.

3. The contamination is a per-trial phenomenon in this paradigm
- In Action Main, each tone is preceded by a keypress.
- Motor activity and timing variability are trial-specific, so subtraction should be applied per trial after proper keypress alignment.

4. Trial-level processing supports better model extensions
- Trial-level subtraction allows later improvement with per-trial scaling/regression if motor contamination amplitude varies.
- ERP-level subtraction makes this difficult and less transparent.

## Recommended Processing Strategy
1. Convert Action Main tone-locked epochs to keypress-locked reference.
2. Apply motor-baseline correction in keypress-locked space.
3. Subtract motor template from each trial (sample-aligned).
4. Convert cleaned trials back to tone-locked reference.
5. Apply identical final baseline correction `[-200, 0] ms re tone` to:
- Action (motor-subtracted)
- No-Action main
6. Compute N1/P2 metrics from these processed datasets.

## Practical Policy for This Pipeline
- Primary analysis: trial-level subtraction.
- Secondary sensitivity check: ERP-level subtraction, but do not overwrite trial data with replicated ERP traces.
- Reporting: state subtraction level explicitly in methods and figure captions.

## Expected Benefits
- Preserves realistic within-condition variance.
- Reduces risk of over-smoothing artifacts.
- Improves interpretability and reproducibility of Action vs No-Action comparisons.
