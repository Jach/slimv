" paredit.vim:
"               Paredit mode for Slimv
" Version:      0.6.0
" Last Change:  31 Mar 2010
" Maintainer:   Tamas Kovacs <kovisoft at gmail dot com>
" License:      This file is placed in the public domain.
"               No warranty, express or implied.
"               *** ***   Use At-Your-Own-Risk!   *** ***
"
" =====================================================================
"
"  Load Once:
if &cp || exists( 'g:paredit_loaded' )
    finish
endif

let g:paredit_loaded = 1

" =====================================================================
"  Global variable definitions
" =====================================================================

" Paredit mode selector
if !exists( 'g:paredit_mode' )
    let g:paredit_mode = 1
endif

" Automatic indentation after some editing commands
if !exists( 'g:paredit_autoindent' )
    let g:paredit_autoindent = 1
endif
let s:indent_never  = 0    " never autoindent
let s:indent_block  = 1    " autoindent after editing a block of text
let s:indent_always = 2    " always autoindent

" Match delimiter this number of lines before and after cursor position
if !exists( 'g:paredit_matchlines' )
    let g:paredit_matchlines = 100
endif

" =====================================================================
"  Other variable definitions
" =====================================================================

" Skip matches inside string or comment
let s:skip_c  = 'synIDattr(synID(line("."), col("."), 0), "name") =~ "comment"'
let s:skip_sc = 'synIDattr(synID(line("."), col("."), 0), "name") =~ "string\\|comment"'

" Regular expressions to identify special characters combinations used by paredit
let s:any_matched_char   = '(\|)\|\[\|\]\|\"'
let s:any_matched_pair   = '()\|\[\]\|\"\"'
let s:any_opening_char   = '(\|\['
let s:any_closing_char   = ')\|\]'
let s:any_openclose_char = '(\|\[\|)\|\]'

" =====================================================================
"  General utility functions
" =====================================================================

" Toggle paredit mode
function! PareditToggle()
    let g:paredit_mode = 1 - g:paredit_mode
    echo g:paredit_mode ? 'Paredit mode on' : 'Paredit mode off'
endfunction

" Does the current syntax item match the given regular expression?
function! s:SynIDMatch( regexp )
    let line = line('.')
    let col  = col('.')
    if col > len( getline( line ) )
        let col = col - 1
    endif
    return synIDattr( synID( line, col, 0), 'name' ) =~ a:regexp
endfunction

" Is the current cursor position inside a comment?
function! PareditInsideComment()
    return s:SynIDMatch( 'comment' )
endfunction

" Is the current cursor position inside a string?
function! PareditInsideString()
    return s:SynIDMatch( 'string' )
endfunction

" Is the current cursor position inside a comment or string?
function! PareditInsideCommentOrString()
    return s:SynIDMatch( 'string\|comment' )
endfunction

" Autoindent current top level form
function! PareditIndentTopLevelForm( level )
    if a:level < g:paredit_autoindent
        return
    endif
    let l = line( '.' )
    let c =  col( '.' )
    normal! ms
    let matchb = max( [l-g:paredit_matchlines, 1] )
    let [l0, c0] = searchpairpos( '(', '', ')', 'brmW', s:skip_sc, matchb )
    "let save_exp = &expandtab
    "set expandtab
    normal! v%=`s
    "let &expandtab = save_exp
endfunction

" Is the current top level form balanced, i.e all opening delimiters
" have a matching closing delimiter
function! PareditIsBalanced()
    let l = line( '.' )
    let c =  col( '.' )
    let line = getline( '.' )
    let matchb = max( [l-g:paredit_matchlines, 1] )
    let matchf = min( [l+g:paredit_matchlines, line('$')] )
    let p1 = searchpair( '(', '', ')', 'brnmW', s:skip_sc, matchb )
    let p2 = searchpair( '(', '', ')',  'rnmW', s:skip_sc, matchf )
    if !(p1 == p2) && !(p1 == p2 - 1 && line[c-1] == '(') && !(p1 == p2 + 1 && line[c-1] == ')')
        " Number of opening and closing parens differ
        return 0
    endif
    let b1 = searchpair( '\[', '', '\]', 'brnmW', s:skip_sc, matchb )
    if b1 == 0
        " Outside of all bracket-pairs
        return 1
    endif
    let b2 = searchpair( '\[', '', '\]',  'rnmW', s:skip_sc, matchf )
    if !(b1 == b2) && !(b1 == b2 - 1 && line[c-1] == '[') && !(b1 == b2 + 1 && line[c-1] == ']')
        " Number of opening and closing brackets differ
        return 0
    endif
    return 1
endfunction

" Insert opening type of a paired character, like ( or [.
function! PareditInsertOpening( open, close )
    if !g:paredit_mode || PareditInsideCommentOrString() || !PareditIsBalanced()
        return a:open
    endif
    let retval = a:open . a:close . "\<Left>"
    let line = getline( '.' )
    let pos = col( '.' ) - 1
    if line[pos] !~ ' \|\\t\|)\|\]'
        let retval = a:open . a:close . " \<Left>\<Left>"
    else
        let retval = a:open . a:close . "\<Left>"
    endif
    if pos > 0 && line[pos-1] !~ ' \|\\t\|(\|\['
        let retval = " " . retval
    endif
    return retval
endfunction

" Find opening matched character
function! PareditFindOpening( open, close, select )
    let open  = escape( a:open , '[]' )
    let close = escape( a:close, '[]' )
    call searchpair( a:open, '', a:close, 'bW', s:skip_sc )
    if a:select
        call searchpair( a:open, '', a:close, 'W', s:skip_sc )
        let save_ve = &ve
        set ve=all 
        normal! lvh
        let &ve = save_ve
        call searchpair( a:open, '', a:close, 'bW', s:skip_sc )
    endif
endfunction

" Find closing matched character
function! PareditFindClosing( open, close, select )
    let open  = escape( a:open , '[]' )
    let close = escape( a:close, '[]' )
    if a:select
        let line = getline( '.' )
        if line[col('.')-1] != a:open
            normal! h
        endif
        call searchpair( a:open, '', a:close, 'W', s:skip_sc )
        call searchpair( a:open, '', a:close, 'bW', s:skip_sc )
        normal! v
        call searchpair( a:open, '', a:close, 'W', s:skip_sc )
        normal! l
    else
        call searchpair( a:open, '', a:close, 'W', s:skip_sc )
    endif
endfunction

" Find beginning of previous element (atom or sub-expression) in a form
" skip_whitespc: skip whitespaces before the previous element
function! PareditFindPrevElement( skip_whitespc )
    let [l0, c0] = [line( '.' ), col( '.' )]
    let symbol_pos = [0, 0]
    let symbol_end = [0, 0]

    while 1
        " Go to previous character
        let [l1, c1] = [line( '.' ), col( '.' )]
        normal! h
        let [l, c] = [line( '.' ), col( '.' )]

        while [l, c] != [l1, c1] && PareditInsideComment()
            " Skip comments
            let [l1, c1] = [l, c]
            normal! h
            let [l, c] = [line( '.' ), col( '.' )]
        endwhile

        while [l, c] == [l1, c1] || PareditInsideComment()
echo input('nl l='.l.' c='.c)
            if symbol_pos != [0, 0]
                let symbol_end = [l, c]
                if !a:skip_whitespc && !PareditInsideString()
                    " Comment before previous symbol
echo input('symbol comment l='.l.' c='.c)
                    call setpos( '.', [0, l0, c0, 0] )
                    return [l, c]
                endif
            endif
            normal! k$
            let [l, c] = [line( '.' ), col( '.' )]
            if [l, c] == [l1, c1]
                " Beginning of file reached: stop
                call setpos( '.', [0, l0, c0, 0] )
                return [0, 0]
            endif
        endwhile

        let line = getline( '.' )
        if PareditInsideString()
echo input('string '.line[c-1].' l='.l.' c='.c)
            let symbol_pos = [l, c]
        elseif symbol_pos == [0, 0]
echo input('no symbol '.line[c-1].' l='.l.' c='.c)
            if line[c-1] =~ s:any_closing_char
                " Skip to the beginning of this sub-expression
                let symbol_pos = [l, c]
                normal! %
            elseif line[c-1] =~ s:any_opening_char
                " Opening delimiter found: stop
                call setpos( '.', [0, l0, c0, 0] )
                return [0, 0]
            elseif line[c-1] =~ '\S'
                " Previous symbol starting
                let symbol_pos = [l, c]
            endif
        else
echo input('symbol '.line[c-1].' l='.l.' c='.c)
            if line[c-1] =~ s:any_opening_char || (a:skip_whitespc && line[c-1] =~ '\S' && symbol_end != [0, 0])
                " Previous symbol beginning reached, opening delimiter or second previous symbol starting
                call setpos( '.', [0, l0, c0, 0] )
                return [l, c+1]
            elseif line[c-1] =~ '\s' || symbol_pos[0] != l
                " Whitespace befire previous symbol
                let symbol_end = [l, c]
                if !a:skip_whitespc
                    call setpos( '.', [0, l0, c0, 0] )
                    return [l, c+1]
                endif
            endif
        endif
    endwhile
endfunction

" Find end of next element (atom or sub-expression) in a form
" skip_whitespc: skip whitespaces after the next element
function! PareditFindNextElement( skip_whitespc )
    let [l0, c0] = [line( '.' ), col( '.' )]
    let symbol_pos = [0, 0]
    let symbol_end = [0, 0]

    while 1
        " Go to next character
        let [l1, c1] = [line( '.' ), col( '.' )]
        normal! l
        let [l, c] = [line( '.' ), col( '.' )]

        " Skip comments
        while [l, c] == [l1, c1] || PareditInsideComment()
"echo input('nl/comment l='.l.' c='.c)
            if symbol_pos != [0, 0]
                let symbol_end = [l, c]
                if !a:skip_whitespc && !PareditInsideString()
                    " Next symbol ended with comment
"echo input('symbol comment l='.l.' c='.c)
                    call setpos( '.', [0, l0, c0, 0] )
                    return [l, c-1]
                endif
            endif
            normal! 0j0
            let [l, c] = [line( '.' ), col( '.' )]
            if [l, c] == [l1, c1]
                " End of file reached: stop
                call setpos( '.', [0, l0, c0, 0] )
                return [0, 0]
            endif
        endwhile

        let line = getline( '.' )
        if PareditInsideString()
"echo input('string '.line[c-1].' l='.l.' c='.c)
            let symbol_pos = [l, c]
        elseif symbol_pos == [0, 0]
"echo input('no symbol '.line[c-1].' l='.l.' c='.c)
            if line[c-1] =~ s:any_opening_char
                " Skip to the end of this sub-expression
                let symbol_pos = [l, c]
                normal! %
            elseif line[c-1] =~ s:any_closing_char
                " Closing delimiter found: stop
                call setpos( '.', [0, l0, c0, 0] )
                return [0, 0]
                "let [l, c] = [0, 0]
                "break
            elseif line[c-1] =~ '\S'
                " Next symbol starting
                let symbol_pos = [l, c]
            endif
        else
"echo input('symbol '.line[c-1].' l='.l.' c='.c)
            if line[c-1] =~ s:any_closing_char || (a:skip_whitespc && line[c-1] =~ '\S' && symbol_end != [0, 0])
                " Next symbol ended, closing delimiter or second next symbol starting
                call setpos( '.', [0, l0, c0, 0] )
                return [l, c-1]
                "let c = c - 1
                "break
            elseif line[c-1] =~ '\s' || symbol_pos[0] != l
                " Next symbol ending with whitespace
                let symbol_end = [l, c]
                if !a:skip_whitespc
                    call setpos( '.', [0, l0, c0, 0] )
                    return [l, c-1]
                    "let c = c - 1
                    "break
                endif
            endif
        endif
    endwhile

"    call setpos( '.', [0, l0, c0, 0] )
"    return [l, c]
endfunction

" Insert closing type of a paired character, like ) or ].
function! PareditInsertClosing( open, close )
    if !g:paredit_mode || PareditInsideCommentOrString() || !PareditIsBalanced()
        return a:close
    endif
    let line = getline( '.' )
    let pos = col( '.' ) - 1
    if line[pos] == a:close
        return "\<Right>"
    else
        let open  = escape( a:open , '[]' )
        let close = escape( a:close, '[]' )
        return "\<C-O>:call searchpair('" . open . "','','" . close . "','W','" . s:skip_sc . "')\<CR>\<Right>"
        "TODO: indent after going to closing character
"        let retval = "\<C-O>:call searchpair('" . open . "','','" . close . "','W','" . s:skip_sc . "')\<CR>"
"        if a:close == ')'
"            let retval = retval . "\<C-O>=[("
"            let retval = retval . "\<C-O>:call searchpair('(','',')','W','" . s:skip_sc . "')\<CR>"
"        endif
"        let retval = retval . "\<Right>"
"        return retval
    endif
endfunction

" Insert an (opening or closing) double quote
function! PareditInsertQuotes()
    if !g:paredit_mode || PareditInsideComment()
        return '"'
    endif
    if PareditInsideString()
        let line = getline( '.' )
        let pos = col( '.' ) - 1
        if line[pos] == '"'
            " Standing on a ", just move to the right
            return "\<Right>"
        elseif (pos > 0 && line[pos-1] == '\') || search('[^\\]"\|^"', 'nW', s:skip_c) == 0
            " We don't have any closing ", insert one
            return '"'
        else
            " Move to the closing "
            return "\<C-O>:call search('" . '[^\\]"\|^"' . "','eW','" . s:skip_c . "')\<CR>\<Right>"
        endif
    else
        " Outside of string: insert a pair of ""
        return '""' . "\<Left>"
    endif
endfunction

" Handle <BS> keypress
function! PareditBackspace( repl_mode )
    if a:repl_mode && line( "." ) == line( "'s" ) && col( "." ) <= col( "'s" )
        " No BS allowed before the previous EOF mark in the REPL
        " i.e. don't delete Lisp prompt
        return ""
    endif

    if !g:paredit_mode || PareditInsideComment()
        return "\<BS>"
    endif

    let line = getline( '.' )
    let pos = col( '.' ) - 1

    if pos == 0
        " We are at the beginning of the line
        return "\<BS>"
    elseif line[pos-1] !~ s:any_matched_char
        " Deleting a non-special character
        return "\<BS>"
    elseif line[pos-1] != '"' && !PareditIsBalanced()
        " Current top-form is unbalanced, can't retain paredit mode
        return "\<BS>"
    endif

    if line[pos-1:pos] =~ s:any_matched_pair
        " Deleting an empty character-pair
        return "\<Right>\<BS>\<BS>"
    else
        " Character-pair is not empty, don't delete just move inside
        return "\<Left>"
    endif
endfunction

" Handle <Del> keypress
function! PareditDel()
    if !g:paredit_mode || PareditInsideComment()
        return "\<Del>"
    endif

    let line = getline( '.' )
    let pos = col( '.' ) - 1

    if pos == len(line)
        " We are at the end of the line
        return "\<Del>"
    elseif line[pos] !~ s:any_matched_char
        " Erasing a non-special character
        return "\<Del>"
    elseif line[pos] != '"' && !PareditIsBalanced()
        " Current top-form is unbalanced, can't retain paredit mode
        return "\<Del>"
    elseif pos == 0
        return "\<Right>"
    endif

    if line[pos-1:pos] =~ s:any_matched_pair
        " Erasing an empty character-pair
        return "\<Left>\<Del>\<Del>"
    else
        " Character-pair is not empty, don't erase just move inside
        return "\<Right>"
    endif
endfunction

" Forward erasing a character in normal mode, do not check if current form balanced
function! s:EraseFwd( count )
    let line = getline( '.' )
    let pos = col( '.' ) - 1
    let c = a:count
    while c > 0
        if PareditInsideComment() || ( PareditInsideString() && line[pos] != '"' )
            let line = strpart( line, 0, pos ) . strpart( line, pos+1 )
        elseif pos == len(line)
            " We are at the end of the line
            let line = strpart( line, 0, pos-1 )
        elseif pos > 0 && line[pos-1:pos] =~ s:any_matched_pair
            " Erasing an empty character-pair
            let line = strpart( line, 0, pos-1 ) . strpart( line, pos+1 )
            let pos = pos - 1
            normal! h
        elseif line[pos] =~ s:any_matched_char
            " Character-pair is not empty, don't erase just move inside
            let pos = pos + 1
            normal! l
        else
            " Erasing a non-special character
            let line = strpart( line, 0, pos ) . strpart( line, pos+1 )
        endif
        let c = c - 1
    endwhile
    call setline( '.', line )
endfunction

" Backward erasing a character in normal mode, do not check if current form balanced
function! s:EraseBck( count )
    let line = getline( '.' )
    let pos = col( '.' ) - 1
    let c = a:count
    while c > 0 && pos > 0
        if PareditInsideComment() || ( PareditInsideString() && line[pos-1] != '"' )
            let line = strpart( line, 0, pos-1 ) . strpart( line, pos )
        elseif line[pos-1:pos] =~ s:any_matched_pair
            " Erasing an empty character-pair
            let line = strpart( line, 0, pos-1 ) . strpart( line, pos+1 )
        elseif line[pos-1] !~ s:any_matched_char
            " Erasing a non-special character
            let line = strpart( line, 0, pos-1 ) . strpart( line, pos )
        endif
        normal! h
        let pos = pos - 1
        let c = c - 1
    endwhile
    call setline( '.', line )
endfunction

" Forward erasing a character in normal mode
function! PareditEraseFwd()
    if !g:paredit_mode || !PareditIsBalanced()
        if v:count > 0
            silent execute 'normal! ' . v:count . 'x'
        else
            normal! x
        endif
        return
    endif

    call s:EraseFwd( v:count1 )
endfunction

" Backward erasing a character in normal mode
function! PareditEraseBck()
    if !g:paredit_mode || !PareditIsBalanced()
        if v:count > 0
            silent execute 'normal! ' . v:count . 'X'
        else
            normal! X
        endif
        return
    endif

    call s:EraseBck( v:count1 )
endfunction

" Forward erasing character till the end of line in normal mode
" Keeping the balanced state
function! PareditEraseFwdLine()
    if !g:paredit_mode || !PareditIsBalanced()
        if v:count > 0
            silent execute 'normal! ' . v:count . 'D'
        else
            normal! D
        endif
        return
    endif

    let lastcol = -1
    let lastlen = -1
    while col( '.' ) != lastcol || len( getline( '.' ) ) != lastlen
        let lastcol = col( '.' )
        let lastlen = len( getline( '.' ) )
        call s:EraseFwd( 1 )
    endwhile
endfunction


" Erasing all characters in the line in normal mode
" Keeping the balanced state
function! PareditEraseLine()
    if !g:paredit_mode || !PareditIsBalanced()
        if v:count > 0
            silent execute 'normal! ' . v:count . 'dd'
        else
            normal! dd
        endif
        return
    endif

    let c = v:count1
    while c > 0
        call PareditEraseFwdLine()

        let lastcol = -1
        let lastlen = -1
        while col( '.' ) != lastcol || len( getline( '.' ) ) != lastlen
            let lastcol = col( '.' )
            let lastlen = len( getline( '.' ) )
            call s:EraseBck( 1 )
        endwhile

        if len( getline( '.' ) ) == 0
            normal! dd
        elseif c > 1
            normal! J
        endif
        let c = c - 1
    endwhile

    normal! ==
endfunction

" Move character from [l0, c0] to [l1, c1]
" Set position to [l1, c1]
function! PareditMoveChar( l0, c0, l1, c1 )
    let line = getline( a:l0 )
    let c = line[a:c0-1]
    if a:l1 == a:l0
        " Move character inside line
        if a:c1 > a:c0
            let line = strpart( line, 0, a:c0-1 ) . strpart( line, a:c0, a:c1-a:c0 ) . c . strpart( line, a:c1 )
        else
            let line = strpart( line, 0, a:c1-1 ) . c . strpart( line, a:c1-1, a:c0-a:c1 ) . strpart( line, a:c0 )
        endif
        call setline( '.', line )
        call setpos( '.', [0, a:l1, a:c1, 0] ) 
    else
        " Move character to another line
        let line = strpart( line, 0, a:c0-1 ) . strpart( line, a:c0 )
        call setline( '.', line )
        let line1 = getline( a:l1 )
        if a:c1 > 1
            let line1 = strpart( line1, 0, a:c1 ) . c . strpart( line1, a:c1 )
            call setline( a:l1, line1 )
            call setpos( '.', [0, a:l1, a:c1+1, 0] ) 
        else
            let line1 = c . line1
            call setline( a:l1, line1 )
            call setpos( '.', [0, a:l1, 1, 0] ) 
        endif
    endif
endfunction

" Move delimiter one atom or s-expression to the left
function! PareditMoveLeft()
    let line = getline( '.' )
    let l0 = line( '.' )
    let c0 =  col( '.' )

    if line[c0-1] =~ s:any_closing_char
        let closing = 1
    elseif line[c0-1] =~ s:any_opening_char
        let closing = 0
    else
        " Can move only delimiters
        return
    endif

    let [l1, c1] = PareditFindPrevElement( closing )
    if [l1, c1] == [0, 0]
        " No previous element found
        return
    endif
    call PareditMoveChar( l0, c0, l1, c1 )
    let line = getline( '.' )
    let c =  col( '.' ) - 1
    if closing && line[c+1] !~ '\s\|)'
        " Insert a space after if needed
        execute "normal! a "
        normal! h
    endif
    if !closing && c > 0 && line[c-1] !~ '\s\|('
        " Insert a space before if needed
        execute "normal! i "
        normal! l
    endif
    return
endfunction

" Move delimiter one atom or s-expression to the right
function! PareditMoveRight()
    let line = getline( '.' )
    let l0 = line( '.' )
    let c0 =  col( '.' )

    "if line[c0-1] == '(' || line[c0-1] == '['
    if line[c0-1] =~ s:any_opening_char
        let opening = 1
    "elseif line[c0-1] == ')' || line[c0-1] == ']'
    elseif line[c0-1] =~ s:any_closing_char
        let opening = 0
    else
        " Can move only delimiters
        return
    endif

    let [l1, c1] = PareditFindNextElement( opening )
    if [l1, c1] == [0, 0]
        " No next element found
        return
    endif
    call PareditMoveChar( l0, c0, l1, c1 )
    let line = getline( '.' )
    let c =  col( '.' ) - 1
    if opening && c > 0 && line[c-1] !~ '\s\|('
        " Insert a space before if needed
        execute "normal! i "
        normal! l
    endif
    if !opening && line[c+1] !~ '\s\|)'
        " Insert a space after if needed
        execute "normal! a "
        normal! h
    endif
    return
endfunction

" =====================================================================
"  Keybindings
" =====================================================================

inoremap <buffer> <expr>   (     PareditInsertOpening('(',')')
inoremap <buffer> <expr>   )     PareditInsertClosing('(',')')
inoremap <buffer> <expr>   [     PareditInsertOpening('[',']')
inoremap <buffer> <expr>   ]     PareditInsertClosing('[',']')
inoremap <buffer> <expr>   "     PareditInsertQuotes()
inoremap <buffer> <expr>   <BS>  PareditBackspace(0)
inoremap <buffer> <expr>   <Del> PareditDel()
nnoremap <buffer> <silent> (     :<C-U>call PareditFindOpening('(',')',0)<CR>
nnoremap <buffer> <silent> )     :<C-U>call PareditFindClosing('(',')',0)<CR>
vnoremap <buffer> <silent> (     <Esc>:<C-U>call PareditFindOpening('(',')',1)<CR>
vnoremap <buffer> <silent> )     <Esc>:<C-U>call PareditFindClosing('(',')',1)<CR>
nnoremap <buffer> <silent> <     :<C-U>call PareditMoveLeft()<CR>
nnoremap <buffer> <silent> >     :<C-U>call PareditMoveRight()<CR>
nnoremap <buffer> <silent> x     :<C-U>call PareditEraseFwd()<CR>
nnoremap <buffer> <silent> <Del> :<C-U>call PareditEraseFwd()<CR>
nnoremap <buffer> <silent> X     :<C-U>call PareditEraseBck()<CR>
nnoremap <buffer> <silent> s     :<C-U>call PareditEraseFwd()<CR>i
nnoremap <buffer> <silent> D     :<C-U>call PareditEraseFwdLine()<CR>
nnoremap <buffer> <silent> C     :<C-U>call PareditEraseFwdLine()<CR>A
nnoremap <buffer> <silent> S     0:<C-U>call PareditEraseFwdLine()<CR>A
nnoremap <buffer> <silent> dd    :<C-U>call PareditEraseLine()<CR>
"TODO: add mapping for default behaviour of (), [], ", <Del>, etc
