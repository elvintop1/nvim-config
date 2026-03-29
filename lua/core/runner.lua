local msys2 = require("core.msys2").setup()

local M = {}

local function cmd_quote(s)
  s = tostring(s)
  if s == "" then
    return '""'
  end

  if s:find('[ \t&()<>|^"]') then
    return '"' .. s:gsub('"', '""') .. '"'
  end

  return s
end

local function shescape(s)
  s = tostring(s)

  if msys2.IS_WIN then
    return cmd_quote(s)
  end

  return vim.fn.shellescape(s)
end

local function shell_join(args)
  local escaped = {}
  for _, arg in ipairs(args) do
    table.insert(escaped, shescape(arg))
  end
  return table.concat(escaped, " ")
end

local function calc_float_size()
  local width = math.floor(vim.o.columns * 0.92)
  local height = math.floor(vim.o.lines * 0.80)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0)
  return width, height, row, col
end

local function create_terminal_window(title)
  local buf = vim.api.nvim_create_buf(false, true)
  local width, height, row, col = calc_float_size()

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    style = "minimal",
    title = " " .. (title or "Runner") .. " ",
    title_pos = "center",
  })

  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "runner"
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false

  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, silent = true, desc = "Close runner" })

  vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], {
    buffer = buf,
    silent = true,
    desc = "Terminal normal mode",
  })

  vim.keymap.set("t", "<C-q>", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, silent = true, desc = "Close runner" })

  return buf, win
end

local function open_term(command, title)
  local _, _ = create_terminal_window(title)

  local argv
  if msys2.IS_WIN then
    argv = { "cmd.exe", "/C", command }
  else
    argv = { "sh", "-lc", command }
  end

  vim.fn.termopen(argv, {
    cwd = vim.fn.expand("%:p:h"),
    on_exit = function(_, code)
      if code ~= 0 then
        vim.schedule(function()
          vim.notify(("Process exited with code %d"):format(code), vim.log.levels.WARN, {
            title = title or "Runner",
          })
        end)
      end
    end,
  })

  vim.cmd("startinsert")
end

local function get_output_path()
  local stem = vim.fn.expand("%:t:r")
  local out_dir = vim.fn.stdpath("cache") .. "/runner"
  vim.fn.mkdir(out_dir, "p")
  local suffix = msys2.IS_WIN and ".exe" or ""
  return out_dir .. "/" .. stem .. suffix
end

local function python_command(file)
  if msys2.IS_WIN and vim.fn.executable("py") == 1 then
    return shell_join({ "py", "-3", file })
  end

  if vim.fn.executable("python") == 1 then
    return shell_join({ "python", file })
  end

  return shell_join({ "python3", file })
end

local function r_command(file)
  if vim.fn.executable("Rscript") == 1 then
    return shell_join({ "Rscript", file })
  end

  return shell_join({ "Rscript.exe", file })
end

function M.build_command()
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")
  local dir = vim.fn.expand("%:p:h")
  local filename = vim.fn.expand("%:t")
  local out = get_output_path()

  if ft == "cpp" then
    return shell_join({
      msys2.get_cpp_compiler(),
      "-std=gnu++17",
      "-O2",
      "-Wall",
      "-Wextra",
      "-Wshadow",
      file,
      "-o",
      out,
    })
  elseif ft == "c" then
    return shell_join({
      msys2.get_c_compiler(),
      "-std=c17",
      "-O2",
      "-Wall",
      "-Wextra",
      file,
      "-o",
      out,
    })
  elseif ft == "java" then
    return "cd /d " .. shescape(dir) .. " && " .. shell_join({ "javac", filename })
  end

  return nil
end

function M.run_command()
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")
  local dir = vim.fn.expand("%:p:h")
  local filename = vim.fn.expand("%:t")
  local stem = vim.fn.expand("%:t:r")
  local out = get_output_path()

  if ft == "cpp" or ft == "c" then
    local build = M.build_command()
    if build then
      return build .. " && " .. shescape(out)
    end
  elseif ft == "python" then
    return python_command(file)
  elseif ft == "r" then
    return r_command(file)
  elseif ft == "javascript" then
    return shell_join({ "node", file })
  elseif ft == "java" then
    return "cd /d " .. shescape(dir) .. " && " .. shell_join({ "javac", filename }) .. " && " .. shell_join({ "java", stem })
  end

  return nil
end

function M.run_current()
  vim.cmd("write")
  local cmd = M.run_command()

  if not cmd then
    vim.notify("Chưa có lệnh run cho filetype: " .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end

  open_term(cmd, "Run • " .. vim.fn.expand("%:t"))
end

function M.build_current()
  vim.cmd("write")
  local cmd = M.build_command()

  if not cmd then
    vim.notify("Chưa có lệnh build cho filetype: " .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end

  open_term(cmd, "Build • " .. vim.fn.expand("%:t"))
end

function M.run_with_input()
  vim.cmd("write")
  local input_file = vim.fn.input("Input file: ", "input.txt", "file")
  if input_file == nil or input_file == "" then
    return
  end

  local cmd = M.run_command()
  if not cmd then
    vim.notify("Chưa có lệnh run cho filetype: " .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end

  open_term(cmd .. " < " .. shescape(vim.fn.fnamemodify(input_file, ":p")), "Run • " .. vim.fn.expand("%:t"))
end

return M
