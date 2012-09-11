:syntax match xKey /^\s*\$\i\+/
:syntax match xKey /^\s*&call/
:syntax match xKey /\$([^)]*)/
:syntax match xCode /^\s*\$\(subclass\|method\)\s/
:syntax match xCSS /CSS: .*/
:syntax match xHTML /HTML_\I\+/
:syntax match xCode /^\s*\(sub\|fn\|js\|perl\|php\)code:/
:syntax match xInclude /^include.*/
:syntax match xStage /^\(subpage\|page\|form\|table\|fields\|macros\|resource\):/
" Comments with #. Caution with cases CSS color, Perl $#
:syntax match xComment /^\s*#.*/ " Leading # 
:syntax match xComment /\s#\s.*$/ " Trailing [ ]#
:syntax region xComment start=/\/\*/ end=/\*\//
:syntax region dString start=/"/ skip=/\\"/ end=/"/  oneline
:syntax region sString start=/'/ skip=/\\'/ end=/'/  oneline

:syntax match perlKey /^\s*\(push\|shift\|unshift\|pop\|print\|return\|goto\|last\|next\)/

:syntax match perlVar /\(\$\|@\|%\)\i\+/
:syntax match perlKey /^\s*\(our\|my\|package\|use\|require\|sub\)\s/
:syntax region perlRegex start=+\(\([!=][~]\|split\|if\|while\)\s*\)\@<=/+ skip=+\\/+ end=+/[cgimopsx]*+ oneline 

:highlight link dString String
:highlight link sString String
:highlight link xKey Type
:highlight link xCSS Underlined
:highlight link xCode Keyword
:highlight link xStage Keyword
:highlight link xComment Comment
:highlight link xInclude Include
:highlight link xHTML Special

:highlight link perlVar Comment
:highlight link perlKey Keyword
:highlight link perlRegex String
