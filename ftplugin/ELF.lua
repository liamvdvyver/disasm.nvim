local disasm = require("disasm")
if disasm.opts.auto_dump_ELF then
  local filename = vim.fs.abspath(vim.api.nvim_buf_get_name(0))

  disasm.state.bin_buffers[filename] = vim.api.nvim_get_current_buf()
  disasm.cur_bin_fname = filename

  disasm.index_dump(filename)
  disasm.populate_dump(filename)
end
