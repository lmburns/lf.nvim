command! -nargs=* -complete=file Lfnvim lua require('lf').start(<f-args>)

" TODO: Finish this command
" command! -nargs=* -complete=file LfToggle lua require('lf').setup():toggle(<f-args>)

if exists('g:lf_replace_netrw') && g:lf_replace_netrw
  augroup ReplaceNetrwWithLf
    autocmd VimEnter * silent! autocmd! FileExplorer
    autocmd BufEnter * let s:buf_path = expand("%")
          \ | if isdirectory(s:buf_path)
          \ | bdelete!
          \ | call timer_start(100, {->v:lua.require'lf'.start(s:buf_path)})
          \ | endif
  augroup END
endif
