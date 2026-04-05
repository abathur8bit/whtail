# whtail cli utility
A dart **tail** utility that can monitor several files at once, and print the contents in different colors.

I created this utility because the existing `tail` command wasn't cutting it. While it does support 
multiple files, the header that it always shows and lack of colors made following multiple files 
unpleasant. When I tried `multitail`, didn't like it. `lnav` was almost usable except it 
would segfault all the time.

So after having to deal with production support issue, and having to have 4 windows open to tail 4 
files, I decided it was time to open a ChatGPT prompt and create my own quick utility.

## Usage
If you specify the `-d` option, you can start watching file that hasn't been created yet.

```
C:> whtail --help
Usage: dart run whtail.dart [options] file1 [file2 ...]

Examples:
  dart run whtail.dart app.log
  dart run whtail.dart -f app.log ../other.log /var/log/syslog
  dart run whtail.dart -f -d app.log

-f, --follow       Print the last 10 lines, then continue following changes.
-d, --directory    Also watch the parent directory so recreated/rotated files are reattached.
-h, --help         Show help.
```

## Compile to Linux and Windows:

```
dart compile exe bin/whtail.dart -o whtail
dart compile exe bin\whtail.dart -o whtail.exe
```

## Colors
File colors will appear in the following colors: red, green, yellow, blue, purple, cyan, white. Then 
bright version of those colors.

Colors are produced using `ansi` colors, so the terminal needs to support `ansi`.

https://weatheredhiker.com/