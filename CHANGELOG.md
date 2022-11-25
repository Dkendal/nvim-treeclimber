# Changelog

## [Unreleased]

### [0.0.3] - 2022-11-25

- All movement and highlight commands now only work on named nodes. Previously
  when moving to siblings anonymous nodes were also considered. The highlight
  preview showed named nodes creating some confusion.

## [0.0.2] - 2022-11-24

### Fixed

- Uses the correct parser now by relying on `require"nvim-treesitter.parser".get_parser()`,
  was using the filetype previously which doesn't always match the parser name.
