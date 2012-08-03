" Vim syntax file
" Language:     Self-ML (sexpr-based markup language)
" Maintainer:   Jonas Höglund <firefly@firefly.nu>
" Filenames:    *.selfml
" Last Change:  2012-06-20

if exists("b:current_syntax")
  finish
endif


"""" Syntactic entries """"""""""""""""""""""""""""""""""""""""""""""
syn region  selfmlEssExpr          matchgroup=Delimiter start="(" end=")"
\                                  contains=ALL

syn match   selfmlLineComment      "#.*" contains=@Spell
syn region  selfmlBlockComment     start="{#" end="#}"
\                                  contains=selfmlBlockComment

syn region  selfmlQuotedString     start="`" end="`" skip="``"
syn region  selfmlBracketedString  start="\[" end="\]"
\                                  contains=selfmlBracketedString

"syn match   selfmlBareWord         "[^\s\[\(#`][^\s]\+"


"""" Highlighting """""""""""""""""""""""""""""""""""""""""""""""""""
hi def link  selfmlEssExpr             Literal

hi def link  selfmlLineComment         Comment
hi def link  selfmlBlockComment        Comment

hi def link  selfmlBareWord            Identifier
hi def link  selfmlQuotedString        String
hi def link  selfmlBracketedString     String


let b:current_syntax = "selfml"

