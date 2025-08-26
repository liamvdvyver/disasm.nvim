local M = {}

---@alias filename string full filenames
---@alias line_number integer
---
---@alias instruction_address string hex format, "0xA1B2"
---@alias bin_instruction_index table<filename, table<integer, table<instruction_address>>>
---@alias buflist table<filename, bufnr> binary name -> objdump bufnr.
---@alias binlist table<filename, bin_instruction_index> binary_name -> instruction index.

---@alias bufnr integer
---@alias winnr integer
---@alias winid integer

-- Private helpers

---Gets a binary's objdump.
---@param bin_fname filename
---@return string output of objdump dissassemble.
local get_objdump = function(bin_fname)
  return vim.system({ "objdump", "--disassemble", bin_fname }, { text = true }):wait().stdout
end

--- Parse the DWARF info from an (exsting) ELF file.
--- @param bin_fname filename
--- @return bin_instruction_index
local parse_dwarf = function(bin_fname)
  local decoded = vim.system({ "objdump", "--dwarf=decodedline", bin_fname }, { text = true }):wait().stdout

  local head_line = "Contents of the .debug_line section:"

  local filename_pattern = ".+:$"
  local info_line_suffix_pattern = "%s+%d+%s+0x[0-9a-f]"

  local cur_filename = nil
  local cur_basename = nil
  local ret = {}

  local after_head = vim.fn.split(decoded, head_line)[2]
  for _, ln in ipairs(vim.fn.split(after_head, "\n")) do
    -- Skip blank
    if ln == "" then
      --continue

      -- New file
    elseif string.match(ln, filename_pattern) then
      cur_filename = vim.fn.split(ln, ":")[1]
      cur_basename = vim.fs.basename(cur_filename)

      if not ret[cur_filename] then
        ret[cur_filename] = {}
      end

    -- Entry
    elseif cur_basename and string.match(ln, info_line_suffix_pattern) then
      local matches = vim.fn.split(ln, " \\+")
      local cur_line = tonumber(matches[2])
      if cur_line then
        local instruction_address = matches[3]

        if not ret[cur_filename][cur_line] then
          ret[cur_filename][cur_line] = {}
        end
        ret[cur_filename][cur_line] = vim.tbl_extend("keep", ret[cur_filename][cur_line], { instruction_address })
      end
    end
  end

  -- sort
  for _, t1 in ipairs(ret) do
    for _, t2 in ipairs(t1) do
      t2.sort()
    end
  end
  return ret
end

---Find line numbers in objdump buffer matching hex addresses.
---@param dump_bufnr bufnr
---@param addrs table<instruction_address>
---@return table<line_number>
local get_objdump_linenrs = function(dump_bufnr, addrs)
  local ret = {}
  local n_addrs = #addrs
  local cur_addr_idx = 1

  for nr, line in ipairs(vim.api.nvim_buf_get_lines(dump_bufnr, 0, -1, 1)) do
    local cur_addr_pat = "^ +" .. string.sub(addrs[cur_addr_idx], 3)
    if string.find(line, cur_addr_pat) then
      ret[#ret + 1] = nr
      cur_addr_idx = cur_addr_idx + 1
      if cur_addr_idx > n_addrs then
        return ret
      end
    end
  end
  return ret
end

-- Public

--- @type { bin_buffers: buflist, bin_indices: table<filename, bin_instruction_index>}
M.state = {
  bin_buffers = {},
  bin_indices = {},
  cur_bin_fname = nil,
}

---Adds a binary file, if it is not added, creates an empty buffer.
---@param filename filename
---@return bufnr
M.add_file = function(filename)
  local bufnr = M.state.bin_buffers[filename]
  if not bufnr then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, filename)
    M.state.bin_buffers[filename] = bufnr
  end
  return bufnr
end

---Parses debug info for a binary file.
---@param filename filename
M.index_dump = function(filename)
  M.state.bin_indices[filename] = parse_dwarf(filename)
end

---Generates objdump, and populates the (existing) buffer for a binary file.
---@param filename filename
M.populate_dump = function(filename)
  local bufnr = M.state.bin_buffers[filename]
  local dump = get_objdump(filename)

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.split(dump, "\n"))
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
end

---Opens the buffer for binary file in a split, if not already open.
---Adds if neccessary.
---@return winid
---@param filename filename
M.open_dump = function(filename)
  M.cur_bin_fname = filename

  local bufnr = M.state.bin_buffers[filename]
  if not bufnr then
    bufnr = M.add_file(filename)
    M.index_dump(filename)
  end
  --Incase buffer was deleted
  M.populate_dump(filename)
  local existing = vim.fn.bufwinid(bufnr)
  if existing > 0 then
    return existing
  else
    return vim.api.nvim_open_win(bufnr, false, { split = "right", win = vim.api.nvim_get_current_win() })
  end
end

---Finds instructions generated from the current line in the given binary file.
---Opens a window to view the objump if not already open,
---and populates its location list.
M.find_instructions = function(filename)
  local winnr = M.open_dump(filename)
  local src_file = vim.api.nvim_buf_get_name(0)
  local cursor_ln = vim.api.nvim_win_get_cursor(0)[1]

  local bin_idx = M.state.bin_indices[filename]
  if not bin_idx then
    return
  end

  local ins_addrs = M.state.bin_indices[filename][src_file][cursor_ln]
  if not ins_addrs then
    return
  end

  local bin_bufnr = M.state.bin_buffers[filename]
  local list = {}
  for i, linenr in ipairs(get_objdump_linenrs(bin_bufnr, ins_addrs)) do
    list[i] = {
      lnum = linenr,
    }
  end

  vim.fn.setloclist(winnr, list, "r")
  vim.api.nvim_win_set_cursor(winnr, { list[1].lnum, 0 })
end

M.setup = function(_)
  vim.api.nvim_create_user_command("Disasm", function(params)
    local bin_fname = vim.fs.abspath(params.fargs[1] or M.cur_bin_fname)
    if params.bang then
      M.populate_dump(bin_fname)
    end
    M.open_dump(bin_fname)
  end, { nargs = "?", complete = "file" })

  vim.api.nvim_create_user_command("DisasmLine", function(params)
    local bin_fname = vim.fs.abspath(params.fargs[1] or M.cur_bin_fname)
    if params.bang then
      M.populate_dump(bin_fname)
    end
    M.find_instructions(bin_fname)
  end, { nargs = "?", complete = "file" })
end

return M
