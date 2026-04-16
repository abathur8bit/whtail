# whtail cli utility
A dart **tail** utility that can monitor several files at once, and print the contents in different colors.

## Usage
```
C:> whtail --help
A tail utility that can monitor several files at once, and print the contents in different colors.
Version: 1.1.0

Homepage: https://weatheredhiker.com/pages/whtail.html
Source  : https://github.com/abathur8bit/whtail
Issues  : https://github.com/abathur8bit/whtail/issues

Usage: whtail [options] file1 [file2 ...]

-f, --follow       Print the last 10 lines, then continue following changes.
-d, --directory    Don't watch the parent directory, so recreated/rotated files are not reattached.
-c, --nocolor      Turn off colors
-h, --help         Show help.

Examples:
  whtail app.log
  whtail -f app.log ../other.log /var/log/syslog
  whtail -f -d app.log
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

https://weatheredhiker.com/pages/whtail.html