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

require "optparse"

require "groonga/command/parser"

module Groonga
  module Command
    class Parser
      module Command
        class GroongaCommandLogicalify
          def initialize
            @logical_table = nil
            @shard_key = nil
          end

          def run(argv=ARGV)
            begin
              parse_options!(argv)
            rescue OptionParser::ParseError
              puts($!.message)
              return false
            end

            input_paths = argv
            if input_paths.empty?
              logicalify($stdin)
            else
              input_paths.each do |input_path|
                File.open(input_path) do |input|
                  logicalify(input)
                end
              end
            end

            true
          end

          private
          def parse_options!(argv)
            option_parser = OptionParser.new
            option_parser.banner += " INPUT_PATH1 INPUT_PATH2 ..."
            option_parser.version = VERSION

            option_parser.on("--logical-table=TABLE",
                             "Use TABLE as logical table name",
                             "[#{@logical_table}]") do |logical_table|
              @logical_table = logical_table
            end

            option_parser.on("--shard-key=COLUMN",
                             "Use COLUMN as shard key",
                             "[#{@shard_key}]") do |shard_key|
              @shard_key = shard_key
            end

            option_parser.parse!(argv)

            if @logical_table.nil?
              raise OptionParser::ParseError, "--logical-table is missing"
            end

            if @shard_key.nil?
              raise OptionParser::ParseError, "--shard-key is missing"
            end
          end

          def logicalify(input)
            parser = Parser.new
            parser.on_command do |command|
              logicalify_command(command)
            end
            input.each_line do |line|
              parser << line
            end
          end

          def logicalify_command(command)
            case command.name
            when "select"
              logicalify_command_select(command)
            end
          end

          def logicalify_command_select(command)
            min = nil
            max = nil
            case command[:table]
            when /\A#{Regexp.escape(@logical_table)}_(\d{4})(\d{2})(\d{2})\z/
              year = $1.to_i
              month = $2.to_i
              day = $3.to_i
              min = Time.local(year, month, day)
              max = min + (60 * 60 * 24)
            else
              return
            end

            arguments = logicalify_arguments(command.arguments)
            arguments[:min] = format_time(min)
            arguments[:min_border] = "include"
            arguments[:max] = format_time(max)
            arguments[:max_border] = "exclude"
            logical_select = create_logical_select_command(arguments)
            if command.uri_format?
              puts(logical_select.to_uri_format)
            else
              puts(logical_select.to_command_format)
            end
          end

          def create_logical_select_command(arguments)
            name = "logical_select"
            command_class = ::Groonga::Command.find(name)
            command_class.new(name, arguments)
          end

          def logicalify_arguments(arguments)
            arguments = arguments.merge(:logical_table => @logical_table,
                                        :shard_key     => @shard_key)
            arguments.delete(:table)
            arguments
          end

          def format_time(time)
            time.strftime("%Y/%m/%d %H:%M:%S")
          end
        end
      end
    end
  end
end
