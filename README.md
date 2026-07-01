# gitlab-todo.nvim

Open and manage your pending GitLab todos in a Neovim scratch buffer.

---

## Requirements

- **`glab` CLI** — installed and authenticated (`glab auth login`)

---

## Installation

### vim.pack

```lua
vim.pack.add({ "https://github.com/theholocoder/glab-todo.nvim" })
require("glab-todo").setup()
```

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "TheHolocoder/gitlab-todo.nvim",
  cmd = "GlabTodo",
  config = function()
    require("glab-todo").setup()
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "TheHolocoder/gitlab-todo.nvim",
  config = function()
    require("glab-todo").setup()
  end,
}
```

---

## Usage

### Minimal configuration

No options are required — a bare `setup()` call is sufficient:

```lua
require("glab-todo").setup()
```

You can also set a keymap to open the todos buffer:

```lua
vim.keymap.set("n", "<leader>glt", "<CMD>GlabTodo<CR>", { desc = "Open glab todo manager" })
```

### Opening the todos buffer

```vim
:GlabTodo
```

Opens (or focuses) the `glab://todos` scratch buffer in a horizontal split below the current window.

### Marking todos as done

Delete any line(s) corresponding to the todo(s) you want to close, then save:

```vim
:w
```

The plugin diffs the initial IDs against the current buffer content, calls
`glab todo done <id>` for each deleted line, and reloads the list.

### Opening a todo in the browser

Press `<CR>` on any todo line to open the corresponding Issue or MR URL in your default browser (`vim.ui.open`).

---

## Commands

| Command | Description |
|---------|-------------|
| `:GlabTodo` | Open (or focus) the GitLab todos scratch buffer in a split below |

---

## Filetype

The plugin defines a custom filetype **`glabtodo`** with two bundled files:

| File | Purpose |
|------|---------|
| `ftplugin/glabtodo.lua` | Buffer-local options (`cursorline`, `nowrap`, `nonumber`, …) |
| `syntax/glabtodo.vim` | Syntax highlighting (IDs, action keywords, types, timestamps, …) |

Highlight groups link to standard groups (`Identifier`, `Statement`, `Type`,
`Special`, `Directory`, `Comment`, `Title`, `NonText`) and are overridable via
your colorscheme.

---

## Dependencies

- [`glab`](https://gitlab.com/gitlab-org/cli) — the official GitLab CLI.
  Install it and run `glab auth login` before using the plugin.

---

## Contributing

Contributions are welcome via GitLab merge requests.
Please open an MR against the `main` branch with a clear description of the
change and any relevant context.

---

## License

MIT — see [`LICENSE`](LICENSE).  
Copyright (c) 2026 TheHolocoder.
