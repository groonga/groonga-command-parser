# Copyright (C) 2015-2016  Kouhei Sutou <kou@clear-code.com>
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

require "json/stream"

module Groonga
  module Command
    class Parser
      class LoadValuesParser
        attr_writer :on_value
        attr_writer :on_end
        def initialize
          initialize_parser
          @on_value = nil
          @on_end = nil
          @containers = []
          @keys = []
        end

        def <<(data)
          data_size = data.bytesize
          return self if data_size.zero?

          before_pos = @parser.pos
          status = catch do |tag|
            @tag = tag
            begin
              @parser << data
            rescue JSON::Stream::ParserError => error
              pos = @parser.pos
              consumed = pos - before_pos - 1
              raise Error.new(error.message,
                              data[0, consumed],
                              data[consumed..-1])
            end
            :continue
          end

          if status == :done
            pos = @parser.pos
            consumed = pos - before_pos
            if consumed < data_size
              @on_end.call(data[consumed..-1])
            else
              @on_end.call(nil)
            end
          end

          self
        end

        private
        def initialize_parser
          @parser = JSON::Stream::Parser.new
          @parser.singleton_class.__send__(:attr_reader, :pos)
          @parser.end_document do
            throw(@tag, :done)
          end
          @parser.start_object do
            push_container({})
          end
          @parser.end_object do
            pop_container
          end
          @parser.start_array do
            push_container([])
          end
          @parser.end_array do
            pop_container
          end
          @parser.key do |key|
            push_key(key)
          end
          @parser.value do |value|
            push_value(value)
          end
        end

        def push_container(container)
          @containers.push(container)
        end

        def pop_container
          container = @containers.pop
          if @containers.size == 1
            @on_value.call(container)
          else
            push_value(container)
          end
        end

        def push_key(key)
          @keys.push(key)
        end

        def push_value(value)
          container = @containers.last
          case container
          when Hash
            container[@keys.pop] = value
          when Array
            container.push(value)
          end
        end
      end
    end
  end
end
