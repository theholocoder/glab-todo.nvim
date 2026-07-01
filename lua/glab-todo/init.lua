--[[
-- GitLab Todo Manager
--
-- Opens an editable scratch buffer listing pending GitLab todos (via `glab`).
-- Delete lines and save (:w) to mark the corresponding todos as done on GitLab.
-- After processing, the buffer is reloaded with the remaining todos.
--
-- Command: :GlabTodo  (registered by setup())
-- Filetype: glabtodo
-- Buffer name: glab://todos
-- Usage: require('glab-todo').setup()  then :GlabTodo
--]]

local M = {}

M.defaults = {}
M.config   = {}

-- ─── helpers ─────────────────────────────────────────────────────────────────

--- Run a command synchronously; return { code, stdout, stderr }.
---@param argv string[]
---@return vim.SystemCompleted
local function run(argv)
  return vim.system(argv):wait()
end

--- Left-pad a string to `width` characters.
---@param s string
---@param width integer
---@return string
local function lpad(s, width)
  s = tostring(s)
  if #s >= width then return s end
  return string.rep(" ", width - #s) .. s
end

--- Right-pad a string to `width` characters.
---@param s string
---@param width integer
---@return string
local function rpad(s, width)
  s = tostring(s)
  if #s >= width then return s end
  return s .. string.rep(" ", width - #s)
end

--- Truncate a string to `max` characters, appending "…" if cut.
---@param s string
---@param max integer
---@return string
local function trunc(s, max)
  s = tostring(s)
  if #s <= max then return s end
  return s:sub(1, max - 1) .. "…"
end

-- ─── fetch ───────────────────────────────────────────────────────────────────

--- Column widths for the rendered table.
local COL = {
  id      = 8,
  action  = 22,
  type_   = 14,
  title   = 50,
  project = 35,
  created = 0, -- remainder
}

---@class GlabTodo
---@field id      integer
---@field action  string
---@field type_   string
---@field title   string
---@field project string
---@field created string
---@field url     string

--- Parse a JSON item from `glab todo list -F json`.
---@param item table
---@return GlabTodo
local function parse_json_item(item)
  local project = ""
  if type(item.project) == "table" then
    project = tostring(item.project.path_with_namespace or item.project.name or "")
  end

  local title = ""
  local url   = ""
  if type(item.target) == "table" then
    title = tostring(item.target.title or "")
    -- Primary: GitLab REST API provides an absolute web_url on Issue/MR resources.
    -- This works for self-hosted GitLab too.
    url = tostring(item.target.web_url or "")
  end

  -- Fallback: construct from iid + project namespace (assumes gitlab.com host).
  if url == "" and type(item.target) == "table" and type(item.project) == "table" then
    local iid  = item.target.iid
    local proj = item.project.path_with_namespace or item.project.name
    local type_ = tostring(item.target_type or "")
    if iid and proj and proj ~= "" then
      local path_segment = (type_ == "MergeRequest") and "merge_requests" or "issues"
      url = "https://gitlab.com/" .. tostring(proj) .. "/-/" .. path_segment .. "/" .. tostring(iid)
    end
  end

  return {
    id      = tonumber(item.id) or 0,
    action  = tostring(item.action_name or ""),
    type_   = tostring(item.target_type or ""),
    title   = title,
    project = project,
    created = tostring(item.created_at or ""),
    url     = url,
  }
end

--- Fetch todos from GitLab.
--- Returns a list of GlabTodo, plus a boolean `ok` and an error string.
---@return GlabTodo[], boolean, string
function M.fetch_todos()
  local r = run({ "glab", "todo", "list", "-F", "json" })

  if r.code ~= 0 then
    -- glab not authed or unavailable — return empty with the error
    local err = vim.trim(r.stderr or r.stdout or "unknown error")
    return {}, false, err
  end

  local raw = vim.trim(r.stdout or "")
  if raw == "" or raw == "null" then
    return {}, true, ""
  end

  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= "table" then
    -- JSON parse failed — fall back to empty, surface the issue
    return {}, false, "JSON parse error: " .. tostring(decoded)
  end

  local todos = {}
  for _, item in ipairs(decoded) do
    table.insert(todos, parse_json_item(item))
  end
  return todos, true, ""
end

-- ─── render ──────────────────────────────────────────────────────────────────

--- Build the header line.
---@return string
local function header_line()
  return rpad("ID",      COL.id)
    .. "  " .. rpad("ACTION",  COL.action)
    .. "  " .. rpad("TYPE",    COL.type_)
    .. "  " .. rpad("TITLE",   COL.title)
    .. "  " .. rpad("PROJECT", COL.project)
    .. "  " .. "CREATED"
end

--- Build a separator line (dashes).
---@return string
local function separator_line()
  local total = COL.id + 2 + COL.action + 2 + COL.type_ + 2 + COL.title + 2 + COL.project + 2 + 20
  return string.rep("-", total)
end

--- Render a single todo as a formatted line.
--- The ID is always the first whitespace-delimited token (for robust re-parsing).
---@param todo GlabTodo
---@return string
local function render_todo_line(todo)
  return lpad(tostring(todo.id), COL.id)
    .. "  " .. rpad(trunc(todo.action,  COL.action),  COL.action)
    .. "  " .. rpad(trunc(todo.type_,   COL.type_),   COL.type_)
    .. "  " .. rpad(trunc(todo.title,   COL.title),   COL.title)
    .. "  " .. rpad(trunc(todo.project, COL.project), COL.project)
    .. "  " .. todo.created
end

--- Write todos into buffer `buf` and store initial IDs in `vim.b[buf]`.
--- `err_msg` may contain embedded newlines (e.g. multi-line glab stderr);
--- we split them into individual buffer lines and notify the user.
---@param buf integer
---@param todos GlabTodo[]
---@param err_msg string?  optional error message to display instead
function M.render(buf, todos, err_msg)
  vim.bo[buf].modifiable = true

  local lines = {}

  if err_msg and err_msg ~= "" then
    vim.notify("glab-todo: " .. err_msg, vim.log.levels.ERROR)
    table.insert(lines, "-- Error fetching todos --")
    for sub in err_msg:gmatch("[^\n]+") do
      table.insert(lines, sub)
    end
  elseif #todos == 0 then
    table.insert(lines, "-- No pending GitLab todos --")
  else
    table.insert(lines, header_line())
    table.insert(lines, separator_line())
    for _, todo in ipairs(todos) do
      table.insert(lines, render_todo_line(todo))
    end
  end

  local ok, seterr = pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
  if not ok then
    vim.notify("glab-todo: render failed: " .. tostring(seterr), vim.log.levels.ERROR)
  end

  -- Store the set of IDs that were originally loaded (for diffing at save time)
  local ids = {}
  for _, todo in ipairs(todos) do
    table.insert(ids, todo.id)
  end
  vim.b[buf].glab_todo_initial_ids = ids

  -- Store a id→url map for the <CR> keymap to look up without re-parsing lines.
  local urls = {}
  for _, todo in ipairs(todos) do
    urls[todo.id] = todo.url
  end
  vim.b[buf].glab_todo_urls = urls

  vim.bo[buf].modified = false
end

-- ─── save handler ────────────────────────────────────────────────────────────

--- Extract the leading numeric ID from a buffer line.
--- Returns nil if the line has no leading integer.
---@param line string
---@return integer?
local function extract_id(line)
  local s = vim.trim(line)
  local num = s:match("^(%d+)")
  return num and tonumber(num) or nil
end

--- Open the todo on the current line in the user's default browser.
---@param buf integer
local function open_todo(buf)
  local row  = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  local id   = extract_id(line)
  if not id then
    vim.notify("No todo on this line", vim.log.levels.INFO)
    return
  end
  local urls = vim.b[buf].glab_todo_urls or {}
  local url  = urls[id]
  if not url or url == "" then
    vim.notify("No URL available for todo " .. id, vim.log.levels.WARN)
    return
  end
  if vim.ui and vim.ui.open then
    vim.ui.open(url)
  else
    -- Defensive fallback (we target 0.12+ so vim.ui.open should exist).
    -- xdg-open is Linux-only; acceptable given the project's Linux environment.
    vim.fn.system({ "xdg-open", url })
  end
end

--- BufWriteCmd callback: mark deleted todos as done, then reload.
---@param buf integer
function M.on_save(buf)
  local initial_ids = vim.b[buf].glab_todo_initial_ids or {}

  -- Build set of IDs currently present in the buffer
  local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local current_set = {}
  for _, line in ipairs(current_lines) do
    local id = extract_id(line)
    if id then
      current_set[id] = true
    end
  end

  -- Collect IDs that were present before but are now absent (= deleted by user)
  local missing = {}
  for _, id in ipairs(initial_ids) do
    if not current_set[id] then
      table.insert(missing, id)
    end
  end

  -- Mark each missing todo as done
  for _, id in ipairs(missing) do
    local r = run({ "glab", "todo", "done", tostring(id) })
    if r.code ~= 0 then
      vim.notify(
        "glab todo done " .. id .. " failed: " .. vim.trim(r.stderr or "<no stderr>"),
        vim.log.levels.WARN
      )
      -- Continue — don't abort the loop
    end
  end

  -- Reload fresh list regardless (even if nothing was deleted, reset modified flag)
  local todos, ok, err = M.fetch_todos()
  if not ok then
    M.render(buf, {}, err)
  else
    M.render(buf, todos)
  end

  vim.bo[buf].modified = false
end

-- ─── open ────────────────────────────────────────────────────────────────────

--- Open (or focus) the glab todos buffer.
function M.open()
  -- Re-use an existing buffer named "glab://todos" if it exists
  local existing_buf = vim.fn.bufnr("glab://todos")
  local buf

  if existing_buf ~= -1 and vim.api.nvim_buf_is_valid(existing_buf) then
    buf = existing_buf
  else
    -- Create a new scratch buffer
    buf = vim.api.nvim_create_buf(false, true) -- listed=false, scratch=true

    -- Name it so we can find it later
    vim.api.nvim_buf_set_name(buf, "glab://todos")

    -- Buffer options
    -- `acwrite` (not `nofile`) is mandatory: a `nofile` buffer raises
    -- E382 on `:w` *before* BufWriteCmd fires. `acwrite` lets our
    -- BufWriteCmd handle the write, which is exactly the oil.nvim pattern.
    vim.bo[buf].buftype    = "acwrite"
    vim.bo[buf].bufhidden  = "hide"
    vim.bo[buf].swapfile   = false
    vim.bo[buf].filetype   = "glabtodo"
    vim.bo[buf].modifiable = true
    vim.bo[buf].buflisted  = false

    -- Wire BufWriteCmd on this specific buffer so :w triggers our save handler
    vim.api.nvim_create_autocmd("BufWriteCmd", {
      buffer   = buf,
      desc     = "glab-todo: mark deleted todos as done and reload",
      callback = function()
        M.on_save(buf)
      end,
    })

    -- <CR> opens the todo under the cursor in the default browser
    vim.keymap.set("n", "<CR>", function() open_todo(buf) end, {
      buffer  = buf,
      desc    = "Open todo in browser",
      silent  = true,
    })
  end

  -- Open in a horizontal split below the current window (re-use if already visible)
  local already_open = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_set_current_win(win)
      already_open = true
      break
    end
  end

  if not already_open then
    vim.cmd("belowright split")
    vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
  end

  -- Fetch and render
  local todos, ok, err = M.fetch_todos()
  if not ok then
    M.render(buf, {}, err)
  else
    M.render(buf, todos)
  end
end

-- ─── setup ───────────────────────────────────────────────────────────────────

--- Bootstrap the plugin: merge options and register the :GlabTodo command.
--- Must be called explicitly; require('glab-todo') alone has no side-effects.
---@param opts table?
---@return table  M
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})

  vim.api.nvim_create_user_command("GlabTodo", function()
    M.open()
  end, { desc = "Open GitLab todos buffer", force = true })

  return M
end

return M
