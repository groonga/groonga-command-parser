# Copyright (C) 2011-2016  Kouhei Sutou <kou@clear-code.com>
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

class ParserTest < Test::Unit::TestCase
  module ParseTests
    def test_parameters
      select = parse("select",
                     :table => "Users",
                     :filter => "age<=30")
      assert_equal(command("select",
                           "table" => "Users",
                           "filter" => "age<=30",
                           "output_type" => "json"),
                   select)
    end
  end

  class HTTPTest < self
    include GroongaCommandParserTestUtils::HTTPCommandParser

    def test_uri_format?
      command = parse("status")
      assert_predicate(command, :uri_format?)
    end

    def test_command_format?
      command = parse("status")
      assert_not_predicate(command, :command_format?)
    end

    def test_no_value
      path = "/d/select?table=Users&key_only"
      command = Groonga::Command::Parser.parse(path)
      assert_equal({:table => "Users"}, command.arguments)
    end

    def test_bracket
      path = "/d/select?table=Users&drilldown[name].keys=name"
      command = Groonga::Command::Parser.parse(path)
      assert_equal({
                     :table => "Users",
                     :"drilldown[name].keys" => "name",
                   },
                   command.arguments)
    end

    def test_escaped_bracket
      path = "/d/select?table=Users&drilldown%5Bname%5D.keys=name"
      command = Groonga::Command::Parser.parse(path)
      assert_equal({
                     :table => "Users",
                     :"drilldown[name].keys" => "name",
                   },
                   command.arguments)
    end

    def test_custom_prefix
      path = "/db1/select?table=Users"
      command = Groonga::Command::Parser.parse(path)
      assert_equal("/db1", command.path_prefix)
    end

    def test_deep_custom_prefix
      path = "/groonga/db1/select?table=Users"
      command = Groonga::Command::Parser.parse(path)
      assert_equal("/groonga/db1", command.path_prefix)
    end

    def test_no_command_name
      error = Groonga::Command::Parser::Error.new("not completed", "/", "")
      assert_raise(error) do
        Groonga::Command::Parser.parse("/")
      end
    end

    class ParseTest < self
      include ParseTests
    end
  end

  class CommandLineTest < self
    include GroongaCommandParserTestUtils::CommandLineCommandParser

    def test_uri_format?
      command = parse("status")
      assert_not_predicate(command, :uri_format?)
    end

    def test_command_format?
      command = parse("status")
      assert_predicate(command, :command_format?)
    end

    class ParseTest < self
      include ParseTests
    end

    class EventTest < self
      def setup
        @parser = Groonga::Command::Parser.new
      end

      class CommandTest < self
        def test_newline
          parsed_command = nil
          @parser.on_command do |command|
            parsed_command = command
          end

          @parser << "status"
          assert_nil(parsed_command)
          @parser << "\n"
          assert_equal("status", parsed_command.name)
        end

        def test_finish
          parsed_command = nil
          @parser.on_command do |command|
            parsed_command = command
          end

          @parser << "status"
          assert_nil(parsed_command)
          @parser.finish
          assert_equal("status", parsed_command.name)
        end

        def test_empty_line
          parsed_command = nil
          @parser.on_command do |command|
            parsed_command = command
          end

          @parser << "\n"
          assert_nil(parsed_command)

          @parser << "status\n"
          assert_equal("status", parsed_command.name)
        end

        def test_multi_lines
          parsed_commands = []
          @parser.on_command do |command|
            parsed_commands << command
          end

          @parser << <<-COMMAND_LIST.chomp
table_list
status
          COMMAND_LIST
          assert_equal(["table_list"],
                       parsed_commands.collect(&:name))

          @parser.finish
          assert_equal(["table_list", "status"],
                       parsed_commands.collect(&:name))
        end
      end

      class LoadTest < self
        def setup
          super
          @events = []
          @parser.on_load_start do |command|
            @events << [:load_start, command.original_source.dup]
          end
          @parser.on_load_columns do |command, header|
            @events << [:load_columns, command.original_source.dup, header]
          end
          @parser.on_load_value do |command, value|
            @events << [:load_value, command.original_source.dup, value]
          end
          @parser.on_load_complete do |command|
            @events << [:load_complete, command.original_source.dup]
          end
        end

        class URITest < self
          def test_no_values
            uri = "/d/load?table=Users"
            @parser << uri
            @parser << "\n"
            assert_equal([
                           [:load_start, uri],
                           [:load_complete, uri],
                         ],
                         @events)
          end
        end

        class InlineTest < self
          class BracketTest < self
            def test_have_columns
              command_line =
                "load " +
                  "--columns '_key, name' " +
                  "--values '[[\"alice\", \"Alice\"]]' " +
                  "--table Users"
              @parser << command_line
              assert_equal([], @events)
              @parser << "\n"
              assert_equal([
                             [:load_start, command_line],
                             [:load_columns, command_line, ["_key", "name"]],
                             [:load_value, command_line, ["alice", "Alice"]],
                             [:load_complete, command_line],
                           ],
                           @events)
            end

            def test_no_columns
              command_line = "load --values '[[\"_key\"], [1]]' --table IDs"
              @parser << command_line
              assert_equal([], @events)
              @parser << "\n"
              assert_equal([
                             [:load_start, command_line],
                             [:load_columns, command_line, ["_key"]],
                             [:load_value, command_line, [1]],
                             [:load_complete, command_line],
                           ],
                           @events)
            end
          end

          def test_brace
            command_line = "load --values '[{\"_key\": 1}]' --table IDs"
            @parser << command_line
            assert_equal([], @events)
            @parser << "\n"
            assert_equal([
                           [:load_start, command_line],
                           [:load_value, command_line, {"_key" => 1}],
                           [:load_complete, command_line],
                         ],
                         @events)
          end
        end

        class MultiLineTest < self
          class BracketTest < self
            def test_have_columns
              @parser << <<-COMMAND
load --table Users --columns "_key, name"
[
["alice", "Alice"]
]
              COMMAND

              expected_events = []
              expected_events << [:load_start, <<-COMMAND.chomp]
load --table Users --columns "_key, name"
              COMMAND
              expected_events << [:load_columns, <<-COMMAND.chomp, ["_key", "name"]]
load --table Users --columns "_key, name"
              COMMAND
              expected_events << [:load_value, <<-COMMAND, ["alice", "Alice"]]
load --table Users --columns "_key, name"
COMMAND
              expected_events << [:load_complete, <<-COMMAND.chomp]
load --table Users --columns "_key, name"
[
["alice", "Alice"]
]
              COMMAND
              assert_equal(expected_events, @events)
            end

            def test_no_columns
              @parser << <<-COMMAND
load --table Users
[
["_key", "name"],
["alice", "Alice"]
]
              COMMAND

              expected_events = []
              expected_events << [:load_start, <<-COMMAND.chomp]
load --table Users
              COMMAND
              expected_events << [:load_columns, <<-COMMAND, ["_key", "name"]]
load --table Users
              COMMAND
              expected_events << [:load_value, <<-COMMAND, ["alice", "Alice"]]
load --table Users
              COMMAND
              expected_events << [:load_complete, <<-COMMAND.chomp]
load --table Users
[
["_key", "name"],
["alice", "Alice"]
]
              COMMAND
              assert_equal(expected_events, @events)
            end
          end

          def test_brace
            @parser << <<-COMMAND
load --table Users
[
{"_key": "alice", "name": "Alice"},
{"_key": "bob",   "name": "Bob"}
]
            COMMAND

            expected_events = []
            expected_events << [:load_start, <<-COMMAND.chomp]
load --table Users
            COMMAND
            value = {"_key" => "alice", "name" => "Alice"}
            expected_events << [:load_value, <<-COMMAND, value]
load --table Users
            COMMAND
            value = {"_key" => "bob", "name" => "Bob"}
            expected_events << [:load_value, <<-COMMAND, value]
load --table Users
            COMMAND
            expected_events << [:load_complete, <<-COMMAND.chomp]
load --table Users
[
{"_key": "alice", "name": "Alice"},
{"_key": "bob",   "name": "Bob"}
]
            COMMAND
            assert_equal(expected_events, @events)
          end
        end

        def test_multiple_bulk
          @parser << <<-COMMANDS
load --table Users
[
{"_key": "alice", "name": "Alice"}
]

load --table Users
[
{"_key": "bob",   "name": "Bob"}
]
          COMMANDS

          expected_events = []

          expected_events << [:load_start, <<-SOURCE.chomp]
load --table Users
          SOURCE
          value = {"_key" => "alice", "name" => "Alice"}
          expected_events << [:load_value, <<-SOURCE, value]
load --table Users
          SOURCE
          expected_events << [:load_complete, <<-SOURCE.chomp]
load --table Users
[
{"_key": "alice", "name": "Alice"}
]
          SOURCE

          expected_events << [:load_start, <<-SOURCE.chomp]
load --table Users
          SOURCE
          value = {"_key" => "bob", "name" => "Bob"}
          expected_events << [:load_value, <<-SOURCE, value]
load --table Users
          SOURCE
          expected_events << [:load_complete, <<-SOURCE.chomp]
load --table Users
[
{"_key": "bob",   "name": "Bob"}
]
          SOURCE

          assert_equal(expected_events, @events)
        end

        def test_multiple_line
          commands = <<-COMMANDS
load --table Users
[
{"_key": "alice", "name": "Alice"}
]

load --table Users
[
{"_key": "bob",   "name": "Bob"}
]
          COMMANDS
          commands.each_line do |line|
            @parser << line
          end

          expected_events = []

          expected_events << [:load_start, <<-SOURCE.chomp]
load --table Users
          SOURCE
          value = {"_key" => "alice", "name" => "Alice"}
          expected_events << [:load_value, <<-SOURCE, value]
load --table Users
[
          SOURCE
          expected_events << [:load_complete, <<-SOURCE.chomp]
load --table Users
[
{"_key": "alice", "name": "Alice"}
]
          SOURCE

          expected_events << [:load_start, <<-SOURCE.chomp]
load --table Users
          SOURCE
          value = {"_key" => "bob", "name" => "Bob"}
          expected_events << [:load_value, <<-SOURCE, value]
load --table Users
[
          SOURCE
          expected_events << [:load_complete, <<-SOURCE.chomp]
load --table Users
[
{"_key": "bob",   "name": "Bob"}
]
          SOURCE

          assert_equal(expected_events, @events)
        end

        class ErrorTest < self
          def test_location
            message = "record separate comma is missing"
            before = "{\"_key\": \"alice\", \"name\": \"Alice\"}"
            after = "\n{\"_key\": \"bob\""
            error = Groonga::Command::Parser::Error.new(message, before, after)
            assert_equal(<<-EOS.chomp, error.message)
record separate comma is missing:
{"_key": "alice", "name": "Alice"}
                                  ^
{"_key": "bob"
EOS
          end

          def test_no_record_separate_comma
            message = "Expected comma or object or array close: char 37"
            before = <<-BEFORE
[
{"_key": "alice", "name": "Alice"}
            BEFORE
            after = <<-AFTER
{"_key": "bob",   "name": "Bob"}
            AFTER
            error = Groonga::Command::Parser::Error.new(message, before, after)
            assert_raise(error) do
              @parser << <<-EOC
load --table Users
[
{"_key": "alice", "name": "Alice"}
{"_key": "bob",   "name": "Bob"}
EOC
            end
          end

          def test_garbage_before_json
            message = "Expected value: char 0"
            before = ""
            after = <<-AFTER
XXX
[
{"_key": "alice", "name": "Alice"}
]
            AFTER
            error = Groonga::Command::Parser::Error.new(message, before, after)
            assert_raise(error) do
              @parser << <<-JSON
load --table Users
XXX
[
{"_key": "alice", "name": "Alice"}
]
              JSON
            end
          end
        end
      end

      class CommentTest < self
        def test_newline
          parsed_comment = nil
          @parser.on_comment do |comment|
            parsed_comment = comment
          end

          @parser << "# status"
          assert_nil(parsed_comment)
          @parser << "\n"
          assert_equal(" status", parsed_comment)
        end

        def test_finish
          parsed_comment = nil
          @parser.on_comment do |comment|
            parsed_comment = comment
          end

          @parser << "# status"
          assert_nil(parsed_comment)
          @parser.finish
          assert_equal(" status", parsed_comment)
        end
      end
    end
  end
end
