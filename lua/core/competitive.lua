-- Uses argv arrays and the installed Python directly, including on native Windows.
local M = {}
local uv = vim.uv or vim.loop
local is_win = vim.fn.has("win32") == 1

local function read_json(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return nil end
  local decoded, value = pcall(vim.json.decode, table.concat(lines, "\n"))
  return decoded and value or nil
end

function M.installation()
  local marker = read_json(vim.fn.stdpath("config") .. "/.cpw-install.json")
  local prefix = vim.g.cpw_prefix or vim.env.CPW_PREFIX
    or (marker and marker.prefix) or (uv.os_homedir() .. "/.local/share/cpw")
  prefix = vim.fs.normalize(prefix)
  local config = read_json(prefix .. "/config.json")
  if not config then
    vim.notify("CP tools not installed. Run bash setup.sh from this config repository.", vim.log.levels.WARN)
    return nil
  end
  return prefix, config
end

local function current_directory()
  local file = vim.api.nvim_buf_get_name(0)
  if file ~= "" and vim.bo.buftype == "" then
    return vim.fs.dirname(file)
  end
  return vim.fn.getcwd()
end

function M.workspace()
  local matches = vim.fs.find(".cpw.json", { path = current_directory(), upward = true, type = "file" })
  if #matches == 0 then
    vim.notify("No CP workspace. Use :CPNew or :CPReceive first.", vim.log.levels.WARN)
    return nil
  end
  return vim.fs.dirname(matches[1])
end

local function save_current()
  if vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) ~= "" then
    vim.cmd("update")
  end
end

function M.terminal(arguments, directory, on_exit)
  local prefix, config = M.installation()
  if not prefix then return end
  local argv = { config.python, prefix .. "/share/cpw.py" }
  vim.list_extend(argv, arguments)
  local env = {}
  local separator = is_win and ";" or ":"
  env.PATH = table.concat(config.extra_paths or {}, separator) .. separator .. (vim.env.PATH or "")
  vim.cmd("botright 14split")
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buffer)
  vim.bo[buffer].bufhidden = "hide"
  vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { buffer = buffer, silent = true })
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buffer, silent = true })
  local job = vim.fn.jobstart(argv, {
    term = true,
    cwd = directory,
    env = env,
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 then
          vim.notify("cpw exited with code " .. code .. "; see terminal output.", vim.log.levels.WARN)
        end
        if on_exit then on_exit(code) end
      end)
    end,
  })
  if job <= 0 then
    vim.notify("Could not start CP tools. Run :CPDoctor after setup.", vim.log.levels.ERROR)
    return
  end
  vim.cmd("startinsert")
end

function M.test(sanitize)
  local root = M.workspace()
  if not root then return end
  save_current()
  local args = { "test" }
  if sanitize then table.insert(args, "--sanitize") end
  M.terminal(args, root)
end

function M.submit(language)
  local root = M.workspace()
  if not root then return end
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" or vim.bo.buftype ~= "" then
    vim.notify("Open the source file to submit.", vim.log.levels.WARN)
    return
  end
  save_current()
  local args = { "submit", file }
  if language and language ~= "" then vim.list_extend(args, { "--language", language }) end
  M.terminal(args, root)
end

function M.samples()
  local root = M.workspace()
  if root then M.terminal({ "samples" }, root) end
end

function M.new(url, directory)
  if not url or url == "" then
    vim.ui.input({ prompt = "Problem URL: " }, function(value)
      if value and value ~= "" then M.new(value) end
    end)
    return
  end
  if not directory or directory == "" then
    vim.ui.input({ prompt = "Workspace directory: ", completion = "dir" }, function(value)
      if value and value ~= "" then M.new(url, value) end
    end)
    return
  end
  directory = vim.fn.fnamemodify(directory, ":p"):gsub("[/\\]+$", "")
  local original_window = vim.api.nvim_get_current_win()
  M.terminal({ "new", url, directory }, current_directory(), function()
    local source = directory .. "/main.cpp"
    if uv.fs_stat(source) and vim.api.nvim_win_is_valid(original_window) then
      vim.api.nvim_win_call(original_window, function()
        vim.cmd("edit " .. vim.fn.fnameescape(source))
      end)
    end
  end)
end

function M.receive(directory)
  M.terminal({ "receive", "--directory", directory or current_directory() }, current_directory())
end

function M.doctor(browser)
  local args = { "doctor" }
  if browser then table.insert(args, "--browser") end
  M.terminal(args, current_directory())
end

function M.login(site)
  if not site or site == "" then
    vim.ui.input({ prompt = "Judge (codeforces/atcoder/kattis/...): ", default = "codeforces" }, function(value)
      if value and value ~= "" then M.login(value) end
    end)
    return
  end
  M.terminal({ "login", site }, current_directory())
end

function M.setup()
  vim.api.nvim_create_user_command("CPNew", function(opts) M.new(opts.fargs[1], opts.fargs[2]) end, { nargs = "*" })
  vim.api.nvim_create_user_command("CPTest", function(opts) M.test(opts.bang) end, { bang = true })
  vim.api.nvim_create_user_command("CPSubmit", function(opts) M.submit(opts.args) end, { nargs = "?" })
  vim.api.nvim_create_user_command("CPSamples", M.samples, {})
  vim.api.nvim_create_user_command("CPReceive", function(opts) M.receive(opts.args ~= "" and opts.args or nil) end, { nargs = "?", complete = "dir" })
  vim.api.nvim_create_user_command("CPLogin", function(opts) M.login(opts.args) end, { nargs = "?" })
  vim.api.nvim_create_user_command("CPDoctor", function(opts) M.doctor(opts.bang) end, { bang = true })
  local keys = {
    { "n", M.new, "New problem" },
    { "t", M.test, "Test samples" },
    { "s", M.submit, "Submit current source" },
    { "i", M.samples, "Download samples" },
    { "r", M.receive, "Receive Competitive Companion" },
    { "l", M.login, "Judge login" },
    { "d", M.doctor, "Check CP setup" },
  }
  for _, entry in ipairs(keys) do
    vim.keymap.set("n", "<leader>p" .. entry[1], entry[2], { desc = entry[3] })
  end
end

return M
