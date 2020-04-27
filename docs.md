# Syntax
- everything is enclosed in `{}` tags, and everything that isn't will be output
- if you put multiple instructions on the same line, their execution order is implementation-defined
- you can put whitespace basically everywhere inside code tags

## Type definitions
- `digit`: a number between `'0'` and `'0'`
- `alpha`: a lowercase or uppercase letter between `'a'` and `'z'`
- `alphanum`: a chatacter that is either a `digit` or `alpha`, or `'_'`
- `filechar`: a character that is either `alphanum`, `-` or `.`

- `%sep`: a character that is either `','`, `';'` or whitespace
- `%osep`: zero or one `%sep`

- `number`: one or more `digit`s
- `name`: one or more `alphanum`s
- `color`, `gradient`, `gradient2d`, `subp`: a `name`
- `filename`, one or more `filechar`
- `$var`: `'$'`, optionally a `'-'` and then `name`
- `@str`: `'@'` and then `name`

# The language
- This was originally meant to be a way to colorize text, but things got out of hand
- There are a few different kinds of variables
	- `$var`: integer
	- `@str`: string (8bit arrays)
	- `color`: rgb color
	- `gradient`: gradient between 2 colors
	- `gradient2d`: 2d rectangular gradient, between 4 colors
	- `subp`: subprogram
- A variable `$-var` is equal to the opposite value of `$var`, and is read-only
- A variable which has a number as name has a value of the given number, and is read-only
- Marks are not shared between subprograms, but everything else is
- A filename of `-` means either stdin or stdout, depending on data direction

# Command list
## Variable assignment
- `$var '=' number`
- `$var '=' $var`
- `$var %osep $var %osep $var %osep = color`
- `$var '=' '#' @str` *length of string*
- `$var '=' 'b' @str` *first byte of string*

## String assignment
- `@str '=' dstring`
- `@str '=' sstring`
- `@str '=' bstring`
- `@str '=' @str`
- `@str '=' 'b' $var` *char value of variable*

## Arithmetic on variables
- `$var '=' $var '+' $var`
- `$var '=' $var '-' $var`
- `$var '=' $var '*' $var`
- `$var '=' $var '/' $var` *floor division*
- `$var '=' $var '%' $var` *modulo*

## Operations on strings
- `@str '=' @str '+' @str` *concatenation*
- `@str '=' @str ':' $var` *sub-char*
- `@str '=' @str ':' $var '-' $var` *sub-string*
- `@str '=' @str '*' $var` *repeat*

## Conditionals
- `$var '=' $var '==' $var`
- `$var '=' $var '<' $var`
- `$var '=' @str '==' @str`
- `$var '=' @str '<' @str` *inclusion*

## Define colors
- `color '=' number %sep number %sep number`
- `color '=' $var %osep $var %osep $var`
- `color '=' gradient '%' number`
- `color '=' gradient '%' $var`
- `color '=' gradient2d '%' number '%' number`
- `color '=' gradient2d '%' $var '%' $var`

## Define gradients
- `gradient '=' color '-' color`
- `gradient2d '=' gradient '+' gradient`

## Set color
- `color` *foreground*
- `'b' %sep color` *background*
- `gradient '%' number` *foreground*
- `'b' %sep gradient '%' number` *background*
- `gradient2d '%' number '%' number' *foreground*
- `'b' %sep gradient2d '%' number '%' number' *background*
- `'^'` *reset colors*

## Display string
- `@str`
- `@str ':' $var` *sub-char*
- `@str ':' $var '-' $var` *sub-string*

## Markers
- `'!mpush'` *pushes a marker onto the stack*
- `'!mpop'` *pops a marker from the stack*
- `'!mjump' %sep number %osep $var` *pops n markers and jumps to the last, if var is nonzero*

## Subprograms
- `'!sload' %sep subp %sep filename` *loads a subprogram from a file*
- `'!sload' %sep subp %osep @str` *loads a subprogram from a string*
- `'!srun' %sep subp` *runs a subprogram*
- `'!srun' %sep subp %osep $var` *runs a subprogram if var is nonzero*
- `'!sreturn' %osep $var` *exits a subprogram conditionally*

## Output control
- `'!nl` *append a newline*
- `'!cmt'` *discard output*
- `'!wrt' %osep @str` *stores output in variable*
- `'!app' %osep @str` *appends output to variable*

## Input
- `'!read' %sep filename %osep @str` *reads file into string*
- `'!read' %osep @str %osep @str` *reads file specified by string, into string*
- `'!readb' %sep filename %osep @str` *reads binary file into string*
- `'!readb' %osep @str %osep @str` *reads binary file specified by string, into string*

## Crash
- `'!err'` *without message*
- `'!err' %osep @str` *with message*
- `'!err' %osep $var` *conditionally*
- `'!err' %osep @str %osep $var` *conditionally, with message*

## Misc
- ` ` *noop*
- `'{'` *returns an opening brace*

