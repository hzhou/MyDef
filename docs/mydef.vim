:syntax match CallPlace /^\s*\$call\s+@\i\+/
:highlight link CallPlace Special

:syntax match xKey /^\s*\$\i\+/
:syntax match xHTML /^\s*\$Call.*/
:syntax match xPrefix /\$\./
:syntax match xKey /^\s*&call/
:syntax match xKey /^\s*\$(set:.*)/
:syntax match xMacro /\$([^)]*)/

:syntax match xCode /^\s*\$\(subclass\|method\)\s/
:syntax match xHTML /HTML_\I\+/
:syntax match xHTML /BLOCK\|DUMP_STUB/
:syntax match xCode /^\s*\(sub\|fn\|js\|perl\|php\|html\)code:/
:syntax match xStage /^\(subpage\|page\|form\|table\|fields\|macros\|resource\):/
" Comments with #. Caution with cases CSS color, Perl $#
:syntax match xComment /^\s*#[^-].*/ " Leading # 
:syntax match xComment /\s#[ :][^-].*$/ " Trailing [ ]#
:syntax match xCommentImportant /^\s*#[-#].*/  
:syntax match xCommentImportant /\s# -.*$/ " Trailing [ ]# 

:syntax match xHighlight /^.*\(#:\)\@=/
:highlight xHighlight ctermfg=9

:syntax region xComment start=/\/\*/ end=/\*\//

:syntax region dString start=/"/ skip=/\\"/ end=/"/  oneline contains=xMacro
:syntax region sString start=/'/ skip=/\\'/ end=/'/  oneline

:syntax match perlKey /^\s*\(push\|shift\|unshift\|pop\|print\|return\|goto\|last\|next\|break\|continue\)\>/
:syntax match pythonKey /^\s*\(if\|elif\|else\|while\|for\|def\|class\)\>/

:syntax match xLabel /^\s*\i\S\+:/ contains=xCode,xStage
:syntax match xInclude /^\(include\|path\):.*/
:syntax match xCSS /CSS: .*/

:syntax match perlVar /\(\$\|@\|%\)\i\+/
:syntax match perlKey /^\s*\(our\|my\|package\|use\|require\|sub\)\s/
:syntax region perlRegex start=+\(\([!=][~]\|split\|if\|while\)\s*\)\@<=/+ skip=+\\/+ end=+/[cgimopsx]*+ oneline 

:highlight link dString String
:highlight link sString String
:highlight link xKey Type
:highlight link xMacro Type
:highlight link xCSS Underlined
:highlight link xCode Statement
:highlight link xStage Statement
:highlight link xComment NonText
:highlight link xCommentImportant Comment

" :highlight link xInclude Include
:highlight xInclude term=underline cterm=bold ctermfg=81 guifg=#ff80ff
:highlight xLabel term=bold cterm=bold

:highlight link xHTML Special

:highlight link perlVar Comment
:highlight link perlKey Statement
:highlight link pythonKey Type
:highlight link perlRegex String

" :highlight link xPrefix Keyword
" :highlight xPrefix term=bold cterm=bold

