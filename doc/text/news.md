# News

## 1.1.1: 2017-10-31

### Fixes

  * Fixed an infinite loop bug on parsing `load`.

## 1.1.0: 2017-10-30

### Improvements

  * `groonga-command-convert-format`: Stopped to require the last
    newline.

### Fixes

  * Fixed a bug that commands after `load` are ignored on `String`
    parse mode.

## 1.0.9: 2017-01-18

### Improvements

  * Required groonga-command 1.3.2 or later for pretty print.

## 1.0.8: 2017-01-18

### Improvements

  * `groonga-command-convert-format`: Added `--pretty-print` option.

## 1.0.7: 2016-12-20

### Improvements

  * Switched to json-stream from ffi-yajl. Because ffi-yajl doesn't
    work on Windows.

## 1.0.6: 2016-09-12

### Improvements

  * Supported no command name URI such as `/`.

## 1.0.5: 2015-08-08

### Improvements

  * `groonga-command-logicalify`: Added.
  * Supported URI style `load` command that doesn't have `values`
    parameter in path.

### Fixes

  * Fixed a bug that parameter name in URL isn't unescaped.

### Thanks

  * Hiroyuki Sato

## 1.0.4: 2015-05-23

### Improvements

  * Made quoted text handling Groonga compatible.
  * Changed JSON parser to ffi-yajl from yajl-ruby.
    * Supported JRuby by this change.
      [GitHub#1] [Reported by Hiroyuki Sato]
    * Improved performance for large load data.

### Fixes

  * Fixed encoding related parse error on Windows.

### Thanks

  * Hiroyuki Sato

## 1.0.3: 2014-12-12

### Improvements

  * Added "groonga-command-convert-format" command that converts
    command format.

## 1.0.2: 2014-10-02

### Improvements

  * Supported custom prefix URI such as `/groonga/db/select?table=Users`.

## 1.0.1: 2013-10-29

### Improvements

  * Supported backslash escape in single quoted token. It introduces
    another problem that backslash escape is evaluated twice in double
    quoted token. It is TODO item.

## 1.0.0: 2013-09-29

The first release!!! It is extracted from groonga-command gem.
