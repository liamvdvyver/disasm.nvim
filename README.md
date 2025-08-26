# disasm.nvim

View disassembly.

## Installation

Call `require("disasm").setup()`, e.g. with Lazy:

```lua
{
  "liamvdvyver/disasm.nvim",
  opts = {},
}
```

## Requirements

`objdump`: generating disassembly/decoding DWARF info.

## Usage

* Use `:Disasm <file>` to open disassembly of a binary file.
* Use `:DisasmLine <file>` to open disassembly of a binary file and jump to the symbol for the line under the cursor.
* Use either command without a `<file>` argument (e.g. `:DisasmLine`) to use the most recently opened binary file.
* Use either command with a bang (e.g. `:Disasm! file.cpp`) to force a re-index of debug symbols.

## Setup

No options are currently supported.

## TODO

* [ ] Checkhealth for objdump install
* [ ] Infer binary filenames from build system targets, `compile_commands.json`, etc.
* [ ] Follow current line under cursor
* [ ] Coloured objdump viewer
