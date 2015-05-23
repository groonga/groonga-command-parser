# News

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
