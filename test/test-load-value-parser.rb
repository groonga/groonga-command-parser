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

class LoadValuesParserTest < Test::Unit::TestCase
  def setup
    @values = []
    @parser = Groonga::Command::Parser::LoadValuesParser.new
    @parser.on_value = lambda do |value|
      @values << value
    end
    @parser.on_end = lambda do |rest|
    end
  end

  def parse(data)
    data.each_line do |line|
    @parser << line
    end
    @values
  end

  sub_test_case "array" do
    test "empty" do
      assert_equal([[]],
                   parse("[[]]"))
    end

    test "no container" do
      assert_equal([[1, "abc", 2.9]],
                   parse(<<-JSON))
[
[1, "abc", 2.9]
]
      JSON
    end

    test "array" do
      assert_equal([[[1, "abc", 2.9]]],
                   parse(<<-JSON))
[
[[1, "abc", 2.9]]
]
      JSON
    end

    test "object" do
      assert_equal([
                     [
                       {
                         "number" => 1,
                         "string" => "abc",
                         "double" => 2.9,
                       },
                     ],
                   ],
                   parse(<<-JSON))
[
  [
    {
      "number": 1,
      "string": "abc",
      "double": 2.9
    }
  ]
]
      JSON
    end
  end

  sub_test_case "object" do
    test "empty" do
      assert_equal([{}],
                   parse("[{}]"))
    end

    test "no container" do
      assert_equal([
                     {
                       "number" => 1,
                       "string" => "abc",
                       "double" => 2.9,
                     },
                   ],
                   parse(<<-JSON))
[
  {
    "number": 1,
    "string": "abc",
    "double": 2.9
  }
]
      JSON
    end

    test "array" do
      assert_equal([
                     {
                       "array" => [1, "abc", 2.9],
                     },
                   ],
                   parse(<<-JSON))
[
  {
    "array": [1, "abc", 2.9]
  }
]
      JSON
    end

    test "object" do
      assert_equal([
                     {
                       "object" => {
                         "number" => 1,
                         "string" => "abc",
                         "double" => 2.9,
                       },
                     },
                   ],
                   parse(<<-JSON))
[
  {
    "object": {
      "number": 1,
      "string": "abc",
      "double": 2.9
    }
  }
]
[
  1
]
      JSON
    end
  end
end
