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
    @parse_done = false
    @parser.on_end = lambda do |rest|
      @parse_done = true
      @parse_rest = rest
    end
  end

  def parse(data)
    data.each_line do |line|
      @parser << line
      break if @parse_done
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
      JSON
    end
  end

  sub_test_case "error" do
    test "unfinished" do
      assert_equal([
                     {
                       "object" => {
                         "string" => "abc",
                       },
                     },
                   ],
                   parse(<<-JSON))
[
  {
    "object": {
      "string": "abc"
    }
  },
  {
      JSON
      assert_false(@parse_done)
    end

    test "too much" do
      assert_equal([
                     {
                       "object" => {
                         "string" => "abc",
                       },
                     },
                   ],
                   parse(<<-JSON))
[
  {
    "object": {
      "string": "abc"
    }
  }
]garbage
      JSON
      assert_equal([true, "garbage\n"],
                   [@parse_done, @parse_rest])
    end
  end
end
