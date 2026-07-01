" Syntax highlighting for the glabtodo filetype (glab-todo plugin).
" Applied after any built-in rules (there are none for this ft, so this is the
" only source of rules).

if exists("b:current_syntax")
  finish
endif

" ── Header / separator ────────────────────────────────────────────────────────
" All-caps header words (ID, ACTION, TYPE, TITLE, PROJECT, CREATED)
syn match glabtodoHeader    /^\s*\(ID\|ACTION\|TYPE\|TITLE\|PROJECT\|CREATED\)/
" Separator line (dashes)
syn match glabtodoSeparator /^-\+$/

" ── Leading numeric ID ────────────────────────────────────────────────────────
" Must be at the very start of the line (after optional spaces).
syn match glabtodoId        /^\s*\d\+/

" ── Action keyword ────────────────────────────────────────────────────────────
syn keyword glabtodoAction
      \ marked
      \ assigned
      \ review_requested
      \ approval_required
      \ directly_addressed
      \ mentioned
      \ build_failed
      \ unmergeable
      \ merge_request_unmergeable

" ── Target type ───────────────────────────────────────────────────────────────
syn keyword glabtodoTypeIssue Issue
syn keyword glabtodoTypeMR    MergeRequest

" ── Project path (contains a slash: group/project) ───────────────────────────
" Matches tokens of the form <non-space>/<non-space> (namespace/project).
syn match   glabtodoProject  /\S\+\/\S\+/

" ── Created / timestamp column ───────────────────────────────────────────────
" ISO timestamps (e.g. 2024-05-01T12:34:56Z or 2024-05-01T12:34:56.000+00:00)
syn match   glabtodoDate     /\d\{4}-\d\{2}-\d\{2}T\d\{2}:\d\{2}:\d\{2}/

" ── Error / info lines ────────────────────────────────────────────────────────
syn match   glabtodoMeta     /^--.*--$/

" ── Highlight links ──────────────────────────────────────────────────────────
hi def link glabtodoId         Identifier
hi def link glabtodoAction     Statement
hi def link glabtodoTypeIssue  Type
hi def link glabtodoTypeMR     Special
hi def link glabtodoProject    Directory
hi def link glabtodoDate       Comment
hi def link glabtodoHeader     Title
hi def link glabtodoSeparator  NonText
hi def link glabtodoMeta       Comment

let b:current_syntax = "glabtodo"
