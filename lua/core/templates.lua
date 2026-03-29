local M = {}

local uv = vim.uv or vim.loop

local templates_root = vim.fn.stdpath("config") .. "/templates"
local files_root = templates_root .. "/files"
local snippets_root = vim.fn.stdpath("config") .. "/snippets"

local default_templates = {
  cpp = "cpp/cp.cpp",
  py = "python/cp.py",
  java = "java/Main.java",
}

local snippet_categories = {
  ds = "Data structures",
  graph = "Graph / tree / flow",
  math = "Math / number theory",
  string = "String",
  tech = "Techniques / DP",
  geo = "Geometry",
}

local function file_exists(path)
  return uv.fs_stat(path) ~= nil
end

local function normalize_slashes(path)
  return (path or ""):gsub("\\", "/")
end

local function sanitize_identifier(name)
  name = (name or ""):gsub("[^%w_]", "_")
  if name == "" then
    return "Main"
  end
  if name:match("^%d") then
    name = "_" .. name
  end
  return name
end

local function make_replacements()
  local filename = vim.fn.expand("%:t")
  local stem = vim.fn.expand("%:t:r")
  local class_name = sanitize_identifier(stem)

  return {
    ["{{FILENAME}}"] = filename,
    ["{{STEM}}"] = stem,
    ["{{CLASS_NAME}}"] = class_name,
    ["{{DATE}}"] = os.date("%Y-%m-%d"),
  }
end

local function read_template(path)
  if not file_exists(path) then
    return nil, "Template not found: " .. path
  end

  local lines = vim.fn.readfile(path)
  local replacements = make_replacements()

  for i, line in ipairs(lines) do
    for key, value in pairs(replacements) do
      line = line:gsub(key, value)
    end
    lines[i] = line
  end

  return lines
end

local function list_templates(root)
  local results = {}

  local function scan(dir, prefix)
    local fs = vim.fs
    if not fs or not fs.dir then
      return
    end

    for name, kind in fs.dir(dir) do
      local full = dir .. "/" .. name
      local rel = prefix ~= "" and (prefix .. "/" .. name) or name
      if kind == "file" then
        table.insert(results, rel)
      elseif kind == "directory" then
        scan(full, rel)
      end
    end
  end

  if file_exists(root) then
    scan(root, "")
  end

  table.sort(results)
  return results
end

local function replace_buffer(lines)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.modified = true
  vim.cmd("normal! gg")
end

local function insert_lines_at_cursor(lines)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local current = vim.api.nvim_get_current_line()

  if current:match("^%s*$") then
    vim.api.nvim_buf_set_lines(0, row, row + 1, false, lines)
  else
    vim.api.nvim_buf_set_lines(0, row + 1, row + 1, false, lines)
  end

  vim.bo.modified = true
end

local function apply_template(relpath, mode)
  relpath = normalize_slashes(relpath)
  local path = files_root .. "/" .. relpath
  local lines, err = read_template(path)
  if not lines then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  if mode == "replace" then
    replace_buffer(lines)
  else
    insert_lines_at_cursor(lines)
  end
end

local function category_from_filename(name)
  if name == "cpp_ds.json" then
    return "ds"
  elseif name == "cpp_graph.json" then
    return "graph"
  elseif name == "cpp_math.json" then
    return "math"
  elseif name == "cpp_string.json" then
    return "string"
  elseif name == "cpp_techniques.json" then
    return "tech"
  elseif name == "cpp_geometry.json" then
    return "geo"
  end
  return nil
end

local function json_decode(text)
  if vim.json and vim.json.decode then
    return vim.json.decode(text)
  end
  return vim.fn.json_decode(text)
end

local function read_json_file(path)
  if not file_exists(path) then
    return nil
  end

  local ok, decoded = pcall(json_decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok then
    vim.notify("Failed to parse snippet file: " .. path, vim.log.levels.ERROR)
    return nil
  end

  return decoded
end

local function normalize_snippet_lines(body)
  local lines = {}
  if type(body) == "table" then
    for _, line in ipairs(body) do
      table.insert(lines, tostring(line))
    end
  elseif body ~= nil then
    lines = vim.split(tostring(body), "\n", { plain = true })
  end

  for i, line in ipairs(lines) do
    line = line:gsub("\\%$", "$")
    line = line:gsub("%${%d+:([^}]*)}", "%1")
    line = line:gsub("%${%d+|([^}]*)|}", function(choice)
      return choice:match("([^,]+)") or ""
    end)
    line = line:gsub("%${%d+}", "")
    line = line:gsub("%$%d+", "")
    line = line:gsub("%${[%u_][%u%d_]*}", "")
    lines[i] = line
  end

  return lines
end

local function load_snippets(scope)
  scope = scope or "all"
  local items = {}

  local fs = vim.fs
  if not fs or not fs.dir or not file_exists(snippets_root) then
    return items
  end

  for name, kind in fs.dir(snippets_root) do
    if kind == "file" and name:match("%.json$") and name ~= "package.json" then
      local category = category_from_filename(name)
      if category and (scope == "all" or scope == "snippets" or scope == category) then
        local data = read_json_file(snippets_root .. "/" .. name)
        if data then
          local names = vim.tbl_keys(data)
          table.sort(names)
          for _, snippet_name in ipairs(names) do
            local def = data[snippet_name]
            local prefixes = def.prefix
            if type(prefixes) ~= "table" then
              prefixes = { tostring(prefixes or snippet_name) }
            end

            table.insert(items, {
              kind = "snippet",
              category = category,
              name = snippet_name,
              trigger = tostring(prefixes[1] or snippet_name),
              prefixes = prefixes,
              description = tostring(def.description or ""),
              body = normalize_snippet_lines(def.body),
            })
          end
        end
      end
    end
  end

  table.sort(items, function(a, b)
    if a.category ~= b.category then
      return a.category < b.category
    end
    return a.trigger < b.trigger
  end)

  return items
end

local function find_snippet(query, scope)
  query = (query or ""):lower()
  for _, item in ipairs(load_snippets(scope or "all")) do
    if item.trigger:lower() == query or item.name:lower() == query then
      return item
    end
    for _, prefix in ipairs(item.prefixes or {}) do
      if tostring(prefix):lower() == query then
        return item
      end
    end
  end
  return nil
end

local function list_snippet_triggers(scope)
  local triggers = {}
  for _, item in ipairs(load_snippets(scope or "all")) do
    table.insert(triggers, item.trigger)
  end
  return triggers
end

local function insert_snippet(query, scope)
  local item = find_snippet(query, scope)
  if not item then
    vim.notify("Snippet not found: " .. tostring(query), vim.log.levels.ERROR)
    return
  end
  insert_lines_at_cursor(item.body)
end

local function build_picker_items(scope)
  scope = scope or "all"
  local items = {}

  if scope == "all" or scope == "files" then
    for _, rel in ipairs(list_templates(files_root)) do
      table.insert(items, {
        kind = "file",
        relpath = rel,
        label = string.format("[file] %s", rel),
      })
    end
  end

  if scope == "all" or scope == "snippets" or snippet_categories[scope] then
    local snippet_scope = snippet_categories[scope] and scope or "all"
    for _, item in ipairs(load_snippets(snippet_scope)) do
      table.insert(items, {
        kind = "snippet",
        trigger = item.trigger,
        label = string.format("[snip:%s] %s — %s", item.category, item.trigger, item.name),
      })
    end
  end

  return items
end

function M.use_file_template(relpath)
  apply_template(relpath, "replace")
end

function M.insert_snippet(trigger, scope)
  insert_snippet(trigger, scope)
end

function M.pick_template(scope)
  scope = scope or "all"
  local items = build_picker_items(scope)

  if #items == 0 then
    vim.notify("No templates/snippets available for scope: " .. scope, vim.log.levels.WARN)
    return
  end

  vim.ui.select(items, {
    prompt = "Select template or snippet",
    format_item = function(item)
      return item.label
    end,
  }, function(item)
    if not item then
      return
    end

    if item.kind == "file" then
      M.use_file_template(item.relpath)
    else
      M.insert_snippet(item.trigger)
    end
  end)
end

local function default_template_for_current_buffer()
  local ext = vim.fn.expand("%:e")
  return default_templates[ext]
end

function M.apply_default_template_if_new()
  local relpath = default_template_for_current_buffer()
  if not relpath then
    return
  end

  if vim.api.nvim_buf_line_count(0) ~= 1 or vim.api.nvim_get_current_line() ~= "" then
    return
  end

  M.use_file_template(relpath)
end

function M.setup()
  vim.api.nvim_create_user_command("TemplateUse", function(opts)
    M.use_file_template(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return list_templates(files_root)
    end,
    desc = "Replace current buffer with a file template",
  })

  vim.api.nvim_create_user_command("TemplateInsert", function(opts)
    M.insert_snippet(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return list_snippet_triggers("all")
    end,
    desc = "Insert a snippet at cursor",
  })

  vim.api.nvim_create_user_command("SnippetInsert", function(opts)
    M.insert_snippet(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return list_snippet_triggers("all")
    end,
    desc = "Insert a snippet at cursor",
  })

  vim.api.nvim_create_user_command("SnippetPick", function(opts)
    local scope = opts.args ~= "" and opts.args or "snippets"
    if scope == "all" then
      scope = "snippets"
    end
    M.pick_template(scope)
  end, {
    nargs = "?",
    complete = function()
      return { "all", "snippets", "ds", "graph", "math", "string", "tech", "geo" }
    end,
    desc = "Select a snippet from a picker",
  })

  vim.api.nvim_create_user_command("TemplatePick", function(opts)
    local scope = opts.args ~= "" and opts.args or "all"
    M.pick_template(scope)
  end, {
    nargs = "?",
    complete = function()
      return { "all", "files", "snippets", "ds", "graph", "math", "string", "tech", "geo" }
    end,
    desc = "Select a template or snippet from a picker",
  })

  vim.api.nvim_create_user_command("CppTemplate", function(opts)
    M.use_file_template("cpp/" .. opts.args)
  end, {
    nargs = 1,
    complete = function()
      return list_templates(files_root .. "/cpp")
    end,
    desc = "Replace current buffer with a C++ file template",
  })

  vim.api.nvim_create_user_command("CppInsert", function(opts)
    M.insert_snippet(opts.args)
  end, {
    nargs = 1,
    complete = function()
      return list_snippet_triggers("all")
    end,
    desc = "Insert a C++ CP snippet at cursor",
  })

  vim.api.nvim_create_autocmd("BufNewFile", {
    group = vim.api.nvim_create_augroup("UserTemplates", { clear = true }),
    pattern = { "*.cpp", "*.cc", "*.cxx", "*.py", "*.java" },
    callback = function()
      M.apply_default_template_if_new()
    end,
  })
end

return M
