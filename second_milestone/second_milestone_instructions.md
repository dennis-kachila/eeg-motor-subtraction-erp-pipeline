## Second Milestone Instructions

### Scope
Perform a full end-to-end review of the EEG preprocessing and analysis pipeline, covering all stages from raw BDF input to final N1/P2 ERP outputs (Steps 1-7).

### Review Coverage
The review must include both code correctness and signal-processing methodology across:
- Step 1: Preprocessing
- Step 2: Artifact rejection
- Step 3: ICA
- Step 4: IC rejection
- Step 5: Post-ICA processing
- Step 6: Condition extraction and epoching (implemented in first_milestone; reviewed and validated in second_milestone)
- Step 7: ERP computation and N1/P2 outputs (implemented in first_milestone; reviewed and validated in second_milestone)

Specific technical areas to verify include:
- Filtering strategy
- Referencing and rereferencing logic
- Artifact handling
- ICA decomposition and component rejection
- Epoch extraction consistency
- ERP metric computation (N1/P2)

### Required Actions
- Flag any bugs, logic issues, or methodological risks.
- Propose and apply corrections directly in the relevant scripts.
- Document important findings and remaining caveats.

### Project Structure Note
All files relevant to this milestone are located in the `second_milestone` folder.

### Client Message (Reference)
"I'd love to move forward with a second milestone at $150 for a full review of the entire pipeline, from the raw BDF files (I can provide a sample) all the way through to the final N1 and P2 outputs (Steps 1-7). It would purely be a code and methodology review, and if you spot anything worth flagging along the way, that would be greatly appreciated."

