# Sample Datasets

This folder contains one-subject sample EEG datasets used to validate the motor-subtraction ERP pipeline.

## Contents

- `continuous datasets/`
- Post-ICA continuous EEG files for No-Action and Action sessions.

- `epoched datasets/`
- Example epoched `.set` files for adaptation/main/all blocks and action baseline block.

## Intended Use

Use these files to run and verify:
- condition extraction (Step 6),
- motor subtraction + ERP computation (Step 7),
- output figure generation and difference-wave checks.

## Notes

- File names follow the pipeline naming convention where possible.
- Keep this directory for sample/testing data only.
