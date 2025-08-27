local disasm = require("disasm")
if disasm.opts.auto_dump_ELF then
  local magic_num = "\127ELF"
  vim.api.nvim_create_autocmd({ "BufRead" }, {
    callback = function(ev)
      if vim.api.nvim_buf_get_text(ev.buf, 0, 0, 0, 4, {})[1] == magic_num then
        vim.bo.filetype = "ELF"
      end
    end,
  })
end
