# Colorize
A ~~stupid~~ text colorization language

## What even is this?
***I don't know***

This was meant to be a text colorization language, and can be used as such pretty fine.
However, things got out of hand, and now it's turing-complete.
You can generate gradients with it, or, well, basically do anything (but that's not gonna be easy).

## What's it good for?
***Text colorization***

It *is* meant as a text colorization language, so you can define colors and apply them to your text.
It can read its input from stdin or a file, and write its output to stdout or a file.
You can write subprograms that can be loaded and executed by a program, to do complex effects.

## How does it work?
`lua colorize.lua [inputFile.clr [outputFile.ascii]]`

Most things are documented in [`docs.md`](docs.md), but things are not set in stone and can change.
For now, it works with `string.gsub` loops, but ideally I'll rewrite this in moonscript with lpeg.

## What's its license?
MIT
