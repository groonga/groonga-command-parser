# Copyright (C) 2014-2019  Kouhei Sutou <kou@clear-code.com>
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
        class GroongaCommandConvertFormat
          def initialize
            @format = :command
            @uri_prefix = "http://localhost:10041"
            @pretty_print = true
            @elasticsearch_version = 5
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
              convert($stdin)
            else
              input_paths.each do |input_path|
                File.open(input_path) do |input|
                  convert(input)
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

            formats = [:uri, :command, :elasticsearch]
            option_parser.on("--format=FORMAT", formats,
                             "Convert to FORMAT",
                             "Available formats #{formats.join(', ')}",
                             "[#{@format}]") do |format|
              @format = format
            end

            option_parser.on("--uri-prefix=PREFIX",
                             "Add PREFIX to URI",
                             "[#{@uri_prefix}]") do |prefix|
              @uri_prefix = prefix
            end

            option_parser.on("--[no-]pretty-print",
                             "Pretty print",
                             "Available only in command format",
                             "[#{@pretty_print}]") do |boolean|
              @pretty_print = boolean
            end

            option_parser.on("--elasticsearch-version=VERSION",
                             "Specify the Elasticsearch version",
                             "Because the Elasticsearch's import format" +
                                        " differs depending on version",
                             "Currently, we can specify 5, 6, 7, and 8" +
                                                      " in this option",
                             "Available only in elasticsearch format",
                             Integer,
                             "[#{@elasticsearch_version}]") do |version|
              @elasticsearch_version = version
            end

            option_parser.parse!(argv)
          end

          def convert(input)
            parser = Parser.new(need_original_source: false)
            case @format
            when :elasticsearch
              parser.on_load_columns do |command, columns|
                command[:columns] ||= columns.join(",")
              end
              loaded_values = []
              parser.on_load_value do |command, value|
                loaded_values << value
              end
              parser.on_load_complete do |command|
                command[:values] = JSON.generate(loaded_values)
                puts(convert_format(command))
              end
            else
              parser.on_command do |command|
                puts(convert_format(command))
              end
            end
            input.each_line do |line|
              parser << line
            end
            parser.finish
          end

          def convert_format(command)
            case @format
            when :uri
              "#{@uri_prefix}#{command.to_uri_format}"
            when :elasticsearch
              command.to_elasticsearch_format(:version => @elasticsearch_version)
            else
              command.to_command_format(:pretty_print => @pretty_print)
            end
          end
        end
      end
    end
  end
end
