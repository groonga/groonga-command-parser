# -*- coding: utf-8 -*-
#
# Copyright (C) 2015  Kouhei Sutou <kou@clear-code.com>
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

class CommandLineSplitterTest < Test::Unit::TestCase
  def split(command_line)
    splitter = Groonga::Command::Parser::CommandLineSplitter.new(command_line)
    splitter.split
  end

  test "name only" do
    assert_equal(["status"],
                 split("status"))
  end

  sub_test_case "arguments" do
    sub_test_case "no quote" do
      test "value" do
        assert_equal(["select", "Logs"],
                     split("select Logs"))
      end

      test "key and value" do
        assert_equal(["select", "--table", "Logs"],
                     split("select --table Logs"))
      end

      test "multibyte character" do
        assert_equal(["select", "テーブル"],
                     split("select テーブル"))
      end
    end

    sub_test_case "single quote" do
      test "value" do
        assert_equal(["select", "Logs"],
                     split("select 'Logs'"))
      end

      test "key and value" do
        assert_equal(["select", "--table", "Logs"],
                     split("select '--table' 'Logs'"))
      end

      test "space" do
        assert_equal(["select", "Logs Table"],
                     split("select 'Logs Table'"))
      end

      test "escape quote" do
        assert_equal(["select", "Logs \' Table"],
                     split("select 'Logs \\' Table'"))
      end

      test "new line" do
        assert_equal(["select", "Logs \n Table"],
                     split("select 'Logs \\n Table'"))
      end
    end

    sub_test_case "double quote" do
      test "value" do
        assert_equal(["select", "Logs"],
                     split("select \"Logs\""))
      end

      test "key and value" do
        assert_equal(["select", "--table", "Logs"],
                     split("select \"--table\" \"Logs\""))
      end

      test "space" do
        assert_equal(["select", "Logs Table"],
                     split("select \"Logs Table\""))
      end

      test "escape quote" do
        assert_equal(["select", "Logs \" Table"],
                     split("select \"Logs \\\" Table\""))
      end

      test "new line" do
        assert_equal(["select", "Logs \n Table"],
                     split("select \"Logs \\n Table\""))
      end
    end
  end
end
