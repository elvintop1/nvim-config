local uv = vim.uv or vim.loop

local M = {
  initialized = false,
  IS_WIN = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1,
}

local function fs_exists(path)
  return uv.fs_stat(path) ~= nil
end

local function to_windows_path(path)
  return path:gsub("/", "\\")
end

local function prepend_to_path(dir)
  local current = vim.env.PATH or ""
  local sep = M.IS_WIN and ";" or ":"
  local normalized_dir = M.IS_WIN and to_windows_path(dir):lower() or dir
  local normalized_current = M.IS_WIN and current:lower() or current

  if not normalized_current:find(normalized_dir, 1, true) then
    vim.env.PATH = (M.IS_WIN and to_windows_path(dir) or dir) .. sep .. current
  end
end

local function detect_msys2_env(root)
  local candidates = {}

  if type(vim.g.msys2_env) == "string" and vim.g.msys2_env ~= "" then
    table.insert(candidates, vim.g.msys2_env)
  end

  for _, env_name in ipairs({"mingw64" }) do
    if not vim.tbl_contains(candidates, env_name) then
      table.insert(candidates, env_name)
    end
  end

  for _, env_name in ipairs(candidates) do
    if fs_exists(root .. "/" .. env_name .. "/bin/g++.exe") then
      return env_name
    end
  end

  return vim.g.msys2_env or "ucrt64"
end

function M.setup()
  if M.initialized then
    return M
  end

  vim.g.msys2_root = vim.g.msys2_root or "C:/msys64"

  M.root = vim.g.msys2_root
  M.env = detect_msys2_env(M.root)
  M.bin = M.root .. "/" .. M.env .. "/bin"
  M.gxx = M.bin .. "/g++.exe"
  M.gcc = M.bin .. "/gcc.exe"

  vim.g.msys2_env = M.env

  if M.IS_WIN and fs_exists(M.bin) then
    prepend_to_path(M.bin)
  end

  M.initialized = true
  return M
end

function M.fs_exists(path)
  return fs_exists(path)
end

function M.get_cpp_compiler()
  local cfg = M.setup()

  if cfg.IS_WIN and fs_exists(cfg.gxx) then
    return cfg.gxx
  end

  local exepath = vim.fn.exepath("g++.exe")
  if exepath ~= "" then
    return exepath
  end

  exepath = vim.fn.exepath("g++")
  if exepath ~= "" then
    return exepath
  end

  return "g++"
end

function M.get_c_compiler()
  local cfg = M.setup()

  if cfg.IS_WIN and fs_exists(cfg.gcc) then
    return cfg.gcc
  end

  local exepath = vim.fn.exepath("gcc.exe")
  if exepath ~= "" then
    return exepath
  end

  exepath = vim.fn.exepath("gcc")
  if exepath ~= "" then
    return exepath
  end

  return "gcc"
end

return M
