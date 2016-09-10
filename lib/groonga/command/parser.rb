# -*- coding: utf-8 -*-
#
# Copyright (C) 2011-2015  Kouhei Sutou <kou@clear-code.com>
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
          parser.on_load_columns do |command, header|
            yield(:on_load_columns, command, header)
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

      def initialize
        reset
        initialize_hooks
        initialize_load_values_parser
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
          raise Error.new("not completed",
                          @command.original_source.lines.to_a.last,
                          "")
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
        @command.original_source << @buffer
        @load_values_parser << @buffer
        @buffer.clear
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

          @command.original_source = line
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
            @load_values_parser << @command[:values]
            reset
          else
            if @command.original_format == :uri
              on_load_complete(@command)
              reset
            else
              @command.original_source << "\n"
              @loading = true
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
        @buffer = "".force_encoding("ASCII-8BIT")
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
        @load_values_parser.on_end = lambda do |rest|
          if rest
            original_source_size = @command.original_source.size
            @command.original_source.slice!(original_source_size - rest.size,
                                            rest.size)
          end
          on_load_complete(@command)
          reset
        end
      end
    end
  end
end
