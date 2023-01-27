"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"
" Global variables, customize per your install
"
" g:gitBin - Full path to git binary
if !exists("g:gitBin")
  let g:gitBin = '/usr/bin/git'
endif

" g:gitDir - Full path to upstream git tree
if !exists("g:gitDir")
  let g:gitDir = '$HOME/src/linux/.git'
endif

" g:diffBin - Full path to diff utility
if !exists("g:diffBin")
  let g:diffBin = "/usr/bin/diff"
endif

" g:diffFilter - Filter passed to diff utility
if !exists("g:diffFilter")
  let g:diffFilter = "-I'^index.*' -I'^@@ [-+ 0-9,]* @@'"
endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"
" Override the default diff command to include filter
set diffexpr=MyDiff()
function! MyDiff()
  let l:diff = g:diffBin . " " . g:diffFilter
  silent execute "!" . l:diff . " " . v:fname_in . " " . v:fname_new . " > " . v:fname_out
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" ShowLinux
"   hash - git commit hash
"   trim - pass commit message through whitespace trim filter
"   quiet - commit message only
function! ShowLinux(hash, trim, quiet)

  let l:git = g:gitBin . " --git-dir=" . g:gitDir
  let l:cmd = l:git . " show " . a:hash 

  if a:quiet
    let l:cmd .= " --quiet"
  endif

  if a:trim
    let l:cmd .= " | sed '/^Date: /,/^diff --git/{s/^    $//}' 2>&1"
  endif

  return system(l:cmd)

endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" GitFixes
"
function! GitFixes(...)

  " Handle a git hash argument, or try to use the word under the cursor
  let l:hash = a:0 >=1 ? a:1 : expand("<cword>")
  let l:shash = strpart(l:hash,0,12)

  " Show git commit and push through sed regex to remove blank-line
  " indentations
  let l:git = g:gitBin . " --git-dir=" . g:gitDir

  let l:fixes = system(l:git . " log --oneline --grep ^[Ff]ixes.*" . l:shash)
  let l:mentions = system(l:git . " log --oneline --grep " . l:shash)

  execute "topleft 6split git-fixes-" . strpart(l:hash,0,12)
  setlocal syntax=off buftype=nofile

  let l:text = "Fixed-by:\n" . l:fixes . "\nMentioned-by:\n" . l:mentions
  call append(0, split(l:text, '\v\n'))
  :1

  " Go back to the original window
  execute "wincmd p"

endfunction
:command! GF :call GitFixes()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" LinuxCommitDiff - vimdiff the current buffer with a hash from the linus tree.
"   [ hash ] - optional git hash, otherwise current vim word
"
function! LinuxCommitDiff(...)

  " Handle a git hash argument, or try to use the word under the cursor
  let l:hash = a:0 >=1 ? a:1 : expand("<cword>")

  " Show git commit and push through sed regex to remove blank-line
  " indentations
  let l:git = g:gitBin . " --git-dir=" . g:gitDir
  let l:show = ShowLinux(l:hash, 1, 0)

  " Setup current pane: disable syntax highlights, goto line 1, select for diff
  setlocal syntax=off
  :1
  :diffthis

  execute "vsplit linus-" . strpart(l:hash,0,12)

  " Setup new pane: no syntax highlightins, set as not-a-file, dump in output
  " from previous 'git show', goto line 1, select for diff
  setlocal syntax=off buftype=nofile
  call append(0, split(l:show, '\v\n'))
  :1
  :diffthis

endfunction
:command! LCD :call LinuxCommitDiff()


" RemoveEmailHeaders - cleanup email headers (everything up to the first
"                      blank line)
"
function! RemoveEmailHeaders()
  silent 1,/^$/d
endfunction


" RemoveGitFooters - cleanup git format-patch footers (everything after the
"                    last "--" line
"
function! RemoveGitFooters()
  " Git format-patch footers
  if search("^-- $")
    silent $,/^-- $/d
    call append(line('$'), '')
  endif
endfunction


" AutoLinuxDiff - try to find upstream commit hash and automatically launch
"                 the LinuxCommitDiff function
"
function! AutoLinuxDiff()

  setlocal syntax=off buftype=nofile
  call RemoveEmailHeaders()
  call RemoveGitFooters()

  if search("\\cupstream", "n")
    silent execute "normal /\\cupstream\<CR>"
  endif

  if search("\\ccherry", "n")
    silent execute "normal /\\ccherry\<CR>"
  endif

  if search("\\ccommit", "n")
    silent execute "normal /\\ccommit\<CR>"
  endif

  if search("[A-Fa-f0-9]\\{12\\}", "n")
    silent execute "normal /[A-Fa-f0-9]\\{12\\}\<CR>"
    call GitFixes()
    call LinuxCommitDiff()
  endif

endfunction


" LinuxCommitTab - open a git commit hash from the linus tree in a new tab
"   [ hash ] - optional git hash, otherwise current vim word
"
function! LinuxCommitTab(...)

  let l:hash = a:0 >=1 ? a:1 : expand("<cword>")

  " Show git commit and push through sed regex to remove blank-line
  " indentations
  let l:git = g:gitBin . " --git-dir=" . g:gitDir
  let l:show = ShowLinux(l:hash, 0, 0)

  " Setup new pane
  execute ":tabnew"
  setlocal syntax=on filetype=git buftype=nofile
  execute ":file linus-" . strpart(l:hash,0,12)
  call append(0, split(l:show, '\v\n'))
  execute ":1"

endfunction
:command! LCT :call LinuxCommitTab()


function! LinusFileDiff()
  let l:file = substitute(expand('%:p'), "src/[A-Za-z0-9._-]*", "src/kernel/linux", "")

  " Setup current pane: disable syntax highlights, goto line 1, select for diff
  setlocal syntax=off
  :diffthis

  execute "vsplit linus"

  " Setup new pane: no syntax highlightins, set as not-a-file, dump in output
  " from previous 'git show', goto line 1, select for diff
  setlocal syntax=off buftype=nofile modifiable
  execute ":view " . l:file
  :diffthis

endfunction
:command! LFD :call LinusFileDiff()


function! LinusFileTab()
  let l:file = substitute(expand('%:p'), "src/[A-Za-z0-9._-]*", "src/kernel/linux", "")
  execute ":tabnew " . l:file
endfunction
:command! LFT :call LinusFileTab()
