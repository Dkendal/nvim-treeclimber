# Changelog

## [Unreleased]

### Fixed

- Uses the correct parser now by relying on `require"nvim-treesitter.parser".get_parser()`,
  was using the filetype previously which doesn't always match the parser name.
