# Copyright (C) 2019  Kouhei Sutou <kou@clear-code.com>
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
        class GroongaCommandFilter
          def initialize
            @include_tables = {}
            @include_schema = true
            @include_load = true
          end

          def run(argv=ARGV)
            begin
              parse_options!(argv)
            rescue OptionParser::ParseError
              $stderr.puts($!.message)
              return false
            end

            input_paths = argv
            if input_paths.empty?
              filter($stdin)
            else
              input_paths.each do |input_path|
                File.open(input_path) do |input|
                  filter(input)
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

            option_parser.on("--include-column=TABLE.COLUMN",
                             "Remain only TABLE.COLUMN from load data.",
                             "You can specify multiple TABLE.COLUMN by",
                             "specifying this option multiple times.") do |table_column|
              table, column = table_column.split(".", 2)
              @include_tables[table] ||= {}
              @include_tables[table][column] = true
            end

            option_parser.on("--no-include-schema",
                             "Remove schema manipulation commands") do |boolean|
              @include_schema = boolean
            end

            option_parser.on("--no-include-load",
                             "Remove load command") do |boolean|
              @include_load = boolean
            end

            option_parser.parse!(argv)
          end

          def filter(input)
            parser = Parser.new
            parser.on_command do |command|
              filter_command(command)
            end
            parser.on_load_start do |command|
              filter_load_start(command)
            end
            parser.on_load_columns do |command, columns|
              filter_load_columns(command, columns)
            end
            parser.on_load_value do |command, value|
              filter_load_value(command, value)
            end
            parser.on_load_complete do |command|
              filter_load_complete(command)
            end
            parser.on_comment do |comment|
              puts("\##{comment}")
            end
            input.each_line do |line|
              parser << line
            end
            parser.finish
          end

          private
          def filter_command(command)
            return unless @include_schema # TODO: Too loose
            case command
            when TableCreate
              return unless target_table?(command.name)
              puts(command)
            when ColumnCreate
              return unless target_column?(command.table, command.name)
              puts(command)
            else
              puts(command)
            end
          end

          def filter_load_start(command)
            return unless @include_load
            return unless target_table?(command.table)
            puts(command)
            puts("[")
            @need_comma = false
          end

          def filter_load_columns(command, columns)
            return unless @include_load
            columns = extract_target_columns(command.table, columns)
            return if columns.empty?
            print(JSON.generate(columns))
            @need_comma = true
          end

          def filter_load_value(command, value)
            return unless @include_load
            return unless target_table?(command.table)
            value = extract_target_attributes(command.table,
                                              command.columns,
                                              value)
            return if value.empty?
            puts(",") if @need_comma
            print(JSON.generate(value))
            @need_comma = true
          end

          def filter_load_complete(command)
            return unless @include_load
            return unless target_table?(command.table)
            puts(",") if @need_comma
            puts("]")
          end

          def target_table?(table)
            @include_tables.empty? or
              @include_tables.key?(table)
          end

          def target_column?(table, column)
            return true if @include_tables.empty?
            columns = @include_tables[table]
            return false if columns.nil?
            column == "_key" or columns.key?(column)
          end

          def extract_target_columns(table, columns)
            columns.find_all do |column|
              target_column?(table, column)
            end
          end

          def extract_target_attributes(table, columns, value)
            case value
            when ::Array
              value.find_all.each_with_index do |_, i|
                target_column?(table, columns[i])
              end
            when ::Hash
              raise "TODO"
            end
          end
        end
      end
    end
  end
end
