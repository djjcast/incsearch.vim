scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V)
	let s:Input = a:V.import("Over.Input")
endfunction


function! s:_vital_depends()
	return [
\		"Over.Input",
\	]
endfunction


let s:module = {
\	"name" : "Digraphs",
\	"digraphs" : {}
\}

function! s:capture(cmd)
	let verbose_save = &verbose
	let &verbose = 0
	try
		redir => result
		execute "silent!" a:cmd
		redir END
	finally
		let &verbose = verbose_save
	endtry
	return result
endfunction

function! s:digraph() abort
	let x = split(substitute(s:capture(':digraph'), "\n", ' ', 'g'),
	\   '[[:graph:]]\{2}\s.\{1,4}\s\+\d\+\s*\zs')
	let digraphs = map(x, "split(v:val, ' \\+')")
	let r = {}
	for d in digraphs
		let r[d[0]] = len(d) is 3 && d[2] =~# '\d\+' ? nr2char(str2nr(d[2],10))
		\   : len(d) is 2 && d[1] =~# '32' ? nr2char(str2nr(d[1],10))
		\   : ''
	endfor
	return r
endfunction


function! s:module.on_leave(cmdline)
	" Delete cache to handle additional digraphs definition
	let self.digraphs = {}
endfunction

function! s:module.on_char_pre(cmdline)
	if a:cmdline.is_input("\<C-k>")
		if empty(self.digraphs)
			" Get digraphs when inputting <C-k> instead of on_enter because it cause
			" flicker in some environments #107
			let self.digraphs = s:digraph()
		endif
		call a:cmdline.setchar('?')
		let self.prefix_key = a:cmdline.input_key()
		let self.old_line = a:cmdline.getline()
		let self.old_pos  = a:cmdline.getpos()
		return
	elseif exists("self.prefix_key")
\		&& a:cmdline.get_tap_key() == self.prefix_key
		call a:cmdline.setline(self.old_line)
		call a:cmdline.setpos(self.old_pos)
		let x = a:cmdline.input_key()
		let y = s:Input.getchar()
		" For CTRL-K, there is one general digraph: CTRL-K <Space> {char} will
		" enter {char} with the highest bit set.  You can use this to enter
		" meta-characters.
		let char = x ==# "\<Space>" ?
		\	nr2char(char2nr(y) + 128) : get(self.digraphs, x . y, y)
		call a:cmdline.setchar(char)
	endif
endfunction

function! s:module.on_char(cmdline)
	if a:cmdline.is_input("\<C-k>")
		call a:cmdline.tap_keyinput(self.prefix_key)
		call a:cmdline.disable_keymapping()
		call a:cmdline.setpos(a:cmdline.getpos()-1)
	else
		if exists("self.prefix_key")
			call a:cmdline.untap_keyinput(self.prefix_key)
			call a:cmdline.enable_keymapping()
			unlet! self.prefix_key
		endif
	endif
endfunction


function! s:make()
	return deepcopy(s:module)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
