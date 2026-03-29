local msys2 = require("core.msys2").setup()

local M = {}
local ns = vim.api.nvim_create_namespace("mingw64-compiler-check")

local function split_lines(s)
  local t = {}
  s = (s or ""):gsub("\r\n", "\n")
  for line in s:gmatch("[^\n]+") do
    table.insert(t, line)
  end
  return t
end

local function severity_from(kind)
  kind = (kind or ""):lower()

  if kind:find("error", 1, true) then
    return vim.diagnostic.severity.ERROR
  elseif kind:find("warning", 1, true) then
    return vim.diagnostic.severity.WARN
  elseif kind:find("note", 1, true) then
    return vim.diagnostic.severity.INFO
  end

  return vim.diagnostic.severity.HINT
end

local function parse_output(lines, bufname)
  local diags = {}
  local qf = {}

  if type(bufname) ~= "string" or bufname == "" then
    return diags, qf
  end

  bufname = vim.fs.normalize(bufname)

  for _, line in ipairs(lines) do
    local file, lnum, col, kind, msg =
      line:match("^(.-):(%d+):(%d+): ([^:]+): (.*)$")

    if not file then
      file, lnum, kind, msg =
        line:match("^(.-):(%d+): ([^:]+): (.*)$")
      col = "1"
    end

    if type(file) == "string" and lnum and kind and msg then
      local norm_file = vim.fs.normalize(file)

      table.insert(qf, {
        filename = file,
        lnum = tonumber(lnum) or 1,
        col = tonumber(col) or 1,
        text = kind .. ": " .. msg,
        type = kind:lower():find("warning", 1, true) and "W" or "E",
      })

      if norm_file == bufname then
        table.insert(diags, {
          lnum = (tonumber(lnum) or 1) - 1,
          col = math.max((tonumber(col) or 1) - 1, 0),
          severity = severity_from(kind),
          source = "mingw64",
          message = msg,
        })
      end
    end
  end

  return diags, qf
end

function M.check_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if vim.bo[bufnr].buftype ~= "" then
    return
  end

  local ft = vim.bo[bufnr].filetype
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    return
  end

  local cmd

  if ft == "cpp" then
    cmd = {
      msys2.get_cpp_compiler(),
      "-std=gnu++17",
      "-Wall",
      "-Wextra",
      "-Wshadow",
      "-fsyntax-only",
      file,
    }
  elseif ft == "c" then
    cmd = {
      msys2.get_c_compiler(),
      "-std=c17",
      "-Wall",
      "-Wextra",
      "-fsyntax-only",
      file,
    }
  else
    return
  end

  local bufname = file

  vim.system(cmd, {
    text = true,
    cwd = vim.fn.fnamemodify(file, ":h"),
  }, function(res)
    local lines = split_lines((res.stdout or "") .. "\n" .. (res.stderr or ""))
    local diags, qf = parse_output(lines, bufname)

    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      vim.diagnostic.set(ns, bufnr, diags, {})
      vim.fn.setqflist({}, "r", {
        title = "Compiler check • " .. vim.fn.fnamemodify(file, ":t"),
        items = qf,
      })

      if #qf == 0 then
        vim.cmd("cclose")
      end
    end)
  end)
end

function M.check_current()
  vim.cmd("write")
  M.check_buffer(vim.api.nvim_get_current_buf())
end

return M