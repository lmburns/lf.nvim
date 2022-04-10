command! -nargs=* -complete=file Lf lua require('lf').setup():start(<f-args>)

" TODO: Finish this command
" command! -nargs=* -complete=file LfToggle lua require('lf').setup():toggle(<f-args>)

" TODO: Make sure that this works
if exists('g:lf_replace_netrw') && g:lf_replace_netrw
  augroup ReplaceNetrwWithLf
    autocmd VimEnter * silent! autocmd! FileExplorer
    autocmd BufEnter * let s:buf_path = expand("%")
          \ | if isdirectory(s:buf_path)
          \ | bdelete!
          \ | call timer_start(100, {->v:lua.require'lf'.setup():start(s:buf_path)})
          \ | endif
  augroup END
endif
