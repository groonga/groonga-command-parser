#!/usr/bin/env ruby
#
# Copyright (C) 2012-2013  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

$VERBOSE = true

base_dir = File.expand_path(File.join(File.dirname(__FILE__), ".."))
lib_dir = File.join(base_dir, "lib")
test_dir = File.join(base_dir, "test")

require "test-unit"
require "test/unit/notify"

Test::Unit::Priority.enable

groonga_command_dir = File.join(base_dir, "..", "groonga-command")
groonga_command_dir = File.expand_path(groonga_command_dir)
if File.exist?(groonga_command_dir)
  $LOAD_PATH.unshift(File.join(groonga_command_dir, "lib"))
end

$LOAD_PATH.unshift(lib_dir)
$LOAD_PATH.unshift(test_dir)

# TODO: Remove me when suppress warnings patches are merged int
# ffi_yajl.
$VERBOSE = false
require "ffi_yajl/ffi"
$VERBOSE = true

require "groonga-command-parser-test-utils"

ENV["TEST_UNIT_MAX_DIFF_TARGET_STRING_SIZE"] ||= "5000"

exit Test::Unit::AutoRunner.run(true, test_dir)
