# Copyright (C) 2015-2026  Sutou Kouhei <kou@clear-code.com>
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

require "json"

module Groonga
  module Command
    class Parser
      class LoadValuesParser
        attr_writer :on_value
        attr_writer :on_consumed
        attr_writer :on_end
        def initialize
          @parser = JSON::ResumableParser.new
          @on_value = nil
          @on_consumed = nil
          @on_end = nil
          @n_processed_values = 0
        end

        def <<(data)
          data_size = data.bytesize
          return self if data_size.zero?

          @parser << data
          begin
            done = @parser.parse
          rescue JSON::ParserError => error
            consumed = data_size - @parser.rest.bytesize
            raise Error.new(error.message,
                            data[0, consumed],
                            data[consumed..-1])
          end

          if done
            @parser.value[@n_processed_values..-1].each do |value|
              @on_value.call(value)
            end
            @n_processed_values = 0
          else
            partial_value = @parser.partial_value
            if partial_value
              partial_value[@n_processed_values..-2].each do |value|
                @on_value.call(value)
              end
              @n_processed_values = partial_value.size - 1
            end
          end

          consumed = data.bytesize
          consumed -= @parser.rest.bytesize if done
          if consumed > 0
            if consumed < data_size
              @on_consumed.call(data[0, consumed])
            else
              @on_consumed.call(data)
            end
          end

          if done
            if consumed < data_size
              @on_end.call(data[consumed..-1])
            else
              @on_end.call(nil)
            end
          end

          self
        end
      end
    end
  end
end
