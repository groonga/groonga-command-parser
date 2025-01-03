# Copyright (C) 2011-2024  Sutou Kouhei <kou@clear-code.com>
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

require "English"
require "cgi"
require "json"

require "groonga/command"

require "groonga/command/parser/error"
require "groonga/command/parser/command-line-splitter"
require "groonga/command/parser/load-values-parser"
require "groonga/command/parser/version"

module Groonga
  module Command
    class Parser
      class << self

        # parses groonga command or HTTP (starts with "/d/") command.
        # @overload parse(data)
        #   @!macro [new] parser.parse.argument
        #     @param [String] data parsed command.
        #     @return [Groonga::Command] Returns
        #       {Groonga::Command} including parsed data.
        #   @!macro parser.parse.argument
        # @overload parse(data, &block)
        #   @!macro parser.parse.argument
        def parse(data, &block)
          if block_given?
            event_parse(data, &block)
          else
            stand_alone_parse(data)
          end
        end

        private
        def event_parse(data)
          parser = new

          parser.on_command do |command|
            yield(:on_command, command)
          end
          parser.on_load_start do |command|
            yield(:on_load_start, command)
          end
          parser.on_load_columns do |command, columns|
            yield(:on_load_columns, command, columns)
          end
          parser.on_load_value do |command, value|
            yield(:on_load_value, command, value)
          end
          parser.on_load_complete do |command|
            yield(:on_load_complete, command)
          end
          parser.on_comment do |comment|
            yield(:on_comment, comment)
          end

          consume_data(parser, data)
        end

        def stand_alone_parse(data)
          parsed_command = nil

          parser = new
          parser.on_command do |command|
            parsed_command = command
          end
          parser.on_load_columns do |command, columns|
            command[:columns] ||= columns.join(",")
          end
          values = []
          parser.on_load_value do |_, value|
            values << value
          end
          parser.on_load_complete do |command|
            parsed_command = command
            parsed_command[:values] ||= JSON.generate(values)
          end

          consume_data(parser, data)
          if parsed_command.nil?
            if data.respond_to?(:each)
              last_chunk = data.last
            else
              last_chunk = data
            end
            raise Error.new("not completed", last_chunk, "")
          end

          parsed_command
        end

        def consume_data(parser, data)
          if data.respond_to?(:each)
            data.each do |chunk|
              parser << chunk
            end
          else
            parser << data
          end
          parser.finish
        end
      end

      def initialize(options={})
        @need_original_source = options.fetch(:need_original_source, true)
        reset
        initialize_hooks
      end

      # Streaming parsing command.
      # @param [String] chunk parsed chunk of command.
      def <<(chunk)
        @buffer << chunk
        @buffer.force_encoding("ASCII-8BIT")
        consume_buffer
      end

      # Finishes parsing. If Parser is loading values specified "load"
      # command, this method raises {Parser::Error}.
      def finish
        if @loading
          original_source = @command.original_source
          if original_source
            last_line = original_source.lines.to_a.last
          else
            last_line = ""
          end
          raise Error.new("not completed", last_line, "")
        else
          catch do |tag|
            parse_line(@buffer)
          end
        end
      end

      # @overload on_command(command)
      # @overload on_command {|command| }
      def on_command(*arguments, &block)
        if block_given?
          @on_command_hook = block
        else
          @on_command_hook.call(*arguments) if @on_command_hook
        end
      end

      # @overload on_load_start(command)
      # @overload on_load_start {|command| }
      def on_load_start(*arguments, &block)
        if block_given?
          @on_load_start_hook = block
        else
          @on_load_start_hook.call(*arguments) if @on_load_start_hook
        end
      end

      # @overload on_load_columns(command)
      # @overload on_load_columns {|command| }
      def on_load_columns(*arguments, &block)
        if block_given?
          @on_load_columns_hook = block
        else
          @on_load_columns_hook.call(*arguments) if @on_load_columns_hook
        end
      end

      # @overload on_load_value(command)
      # @overload on_load_value {|command| }
      def on_load_value(*arguments, &block)
        if block_given?
          @on_load_value_hook = block
        else
          @on_load_value_hook.call(*arguments) if @on_load_value_hook
        end
      end

      # @overload on_load_complete(command)
      # @overload on_load_complete(command) { }
      def on_load_complete(*arguments, &block)
        if block_given?
          @on_load_complete_hook = block
        else
          @on_load_complete_hook.call(*arguments) if @on_load_complete_hook
        end
      end

      # @overload on_comment(comment)
      # @overload on_comment {|comment| }
      def on_comment(*arguments, &block)
        if block_given?
          @on_comment_hook = block
        else
          @on_comment_hook.call(*arguments) if @on_comment_hook
        end
      end

      private
      def consume_buffer
        catch do |tag|
          loop do
            if @loading
              consume_load_values(tag)
            else
              parse_line(consume_line(tag))
            end
          end
        end
      end

      def consume_load_values(tag)
        throw(tag) if @buffer.empty?
        @load_values_parser << @buffer
      end

      def consume_line(tag)
        current_line, separator, rest = @buffer.partition(/\r?\n/)
        throw(tag) if separator.empty?

        if current_line.end_with?("\\")
          @buffer.sub!(/\\\r?\n/, "")
          consume_line(tag)
        else
          @buffer = rest
          current_line
        end
      end

      def parse_line(line)
        case line
        when /\A\s*\z/
          # ignore empty line
        when /\A\#/
          on_comment($POSTMATCH)
        else
          @command = parse_command(line)
          return if @command.nil?

          @command.original_source = line if @need_original_source
          process_command
        end
      end

      def process_command
        if @command.command_name == "load"
          on_load_start(@command)
          if @command.columns
            on_load_columns(@command, @command.columns)
          end
          if @command[:values]
            initialize_load_values_parser
            @load_values_parser << @command[:values]
            reset
          else
            if @command.original_format == :uri
              on_load_complete(@command)
              reset
            else
              @command.original_source << "\n" if @need_original_source
              @loading = true
              initialize_load_values_parser
            end
          end
        else
          on_command(@command)
          @command = nil
        end
      end

      def parse_command(input)
        if input.start_with?("/")
          parse_uri_path(input)
        else
          parse_command_line(input)
        end
      end

      def parse_uri_path(relative_uri)
        path, arguments_string = relative_uri.split(/\?/, 2)
        arguments = {}
        if arguments_string
          arguments_string.split(/&/).each do |argument_string|
            key, value = argument_string.split(/\=/, 2)
            next if value.nil?
            arguments[CGI.unescape(key)] = CGI.unescape(value)
          end
        end
        if /\/([^\/]*)\z/=~ path
          prefix = $PREMATCH
          name = $1
        else
          prefix = ""
          name = path
        end

        return nil if name.empty?

        name, output_type = name.split(/\./, 2)
        arguments["output_type"] = output_type if output_type
        command_class = ::Groonga::Command.find(name)
        command = command_class.new(name, arguments)
        command.original_format = :uri
        command.path_prefix = prefix
        command
      end

      def parse_command_line(command_line)
        splitter = CommandLineSplitter.new(command_line)
        name, *arguments = splitter.split
        if name.nil?
          raise Error.new("invalid command name",
                          command_line,
                          "")
        end
        pair_arguments = {}
        ordered_arguments = []
        until arguments.empty?
          argument = arguments.shift
          if argument.start_with?("--")
            pair_arguments[argument.sub(/\A--/, "")] = arguments.shift
          else
            ordered_arguments << argument
          end
        end
        command_class = ::Groonga::Command.find(name)
        command = command_class.new(name, pair_arguments, ordered_arguments)
        command.original_format = :command
        command
      end

      def reset
        @command = nil
        @loading = false
        @buffer = +""
        @buffer.force_encoding("ASCII-8BIT")
        @load_values_parser = nil
      end

      def initialize_hooks
        @on_command_hook = nil
        @on_load_start_hook = nil
        @on_load_columns_hook = nil
        @on_load_value_hook = nil
        @on_load_complete_hook = nil
      end

      def initialize_load_values_parser
        @load_values_parser = LoadValuesParser.new
        @load_values_parser.on_value = lambda do |value|
          if value.is_a?(::Array) and @command.columns.nil?
            @command.columns = value
            on_load_columns(@command, value)
          else
            on_load_value(@command, value)
          end
        end
        @load_values_parser.on_consumed = lambda do |consumed|
          if @loading
            @command.original_source << consumed if @need_original_source
            if @buffer.bytesize == consumed.bytesize
              @buffer = +""
              @buffer.force_encoding("ASCII-8BIT")
            else
              @buffer = @buffer[consumed.bytesize..-1]
            end
          end
        end
        @load_values_parser.on_end = lambda do |rest|
          loading = @loading
          on_load_complete(@command)
          reset
          @buffer << rest if loading and rest
        end
      end
    end
  end
end
