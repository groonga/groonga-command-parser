# -*- coding: utf-8 -*-
#
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

# TODO: Remove me when https://github.com/chef/ffi-yajl/pull/62 is merged.
require "stringio"
ENV["FORCE_FFI_YAJL"] = "ffi"
require "ffi_yajl"

module FFI_Yajl
  attach_function :yajl_get_bytes_consumed, [:yajl_handle], :size_t
end

module Groonga
  module Command
    class Parser
      class LoadValuesParser
        attr_writer :on_value
        attr_writer :on_end
        def initialize
          initialize_callbacks
          @handle = nil
          @callbacks_memory = nil
          @on_value = nil
          @on_end = nil
          @containers = []
          @keys = []
        end

        def <<(data)
          data_size = data.bytesize
          return self if data_size.zero?

          ensure_handle

          status = FFI_Yajl.yajl_parse(@handle, data, data_size)

          if status != :yajl_status_ok
            consumed = FFI_Yajl.yajl_get_bytes_consumed(@handle)
            if consumed > 0
              consumed -= 1
            end
            if @containers.empty?
              message = "there are garbages before JSON"
            else
              message = FFI_Yajl.yajl_get_error(@handle, 0, nil, 0).chomp
            end
            begin
              raise Error.new(message,
                              data[0, consumed],
                              data[consumed..-1])
            ensure
              finalize_handle
            end
          end

          if @containers.empty?
            consumed = FFI_Yajl.yajl_get_bytes_consumed(@handle)
            begin
              if consumed < data_size
                @on_end.call(data[consumed..-1])
              else
                @on_end.call(nil)
              end
            ensure
              finalize_handle
            end
          end

          self
        end

        private
        def callback(*arguments)
          FFI::Function.new(:int, [:pointer, *arguments]) do |_, *values|
            yield(*values)
            1
          end
        end

        def initialize_callbacks
          @null_callback = callback do
            push_value(nil)
          end
          @boolean_callback = callback(:int) do |c_boolean|
            push_value(c_boolean != 0)
          end
          @number_callback = callback(:string, :size_t) do |data, size|
            number_data = data.slice(0, size)
            if /[\.eE]/ =~ number_data
              number_data.to_f
            else
              number_data.to_i
            end
          end
          @string_callback = callback(:string, :size_t) do |data, size|
            string = data.slice(0, size)
            string.force_encoding(Encoding::UTF_8)
            push_value(string)
          end
          @start_map_callback = callback do
            push_container({})
          end
          @map_key_callback = callback(:string, :size_t) do |data, size|
            key = data.slice(0, size)
            key.force_encoding(Encoding::UTF_8)
            @keys.push(key)
          end
          @end_map_callback = callback do
            pop_container
          end
          @start_array_callback = callback do
            push_container([])
          end
          @end_array_callback = callback do
            pop_container
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

        def push_value(value)
          container = @containers.last
          case container
          when Hash
            container[@keys.pop] = value
          when Array
            container.push(value)
          end
        end

        def ensure_handle
          return if @handle
          initialize_handle
        end

        def initialize_handle
          @callbacks_memory = FFI::MemoryPointer.new(FFI_Yajl::YajlCallbacks)
          callbacks = FFI_Yajl::YajlCallbacks.new(@callbacks_memory)
          callbacks[:yajl_null] = @null_callback
          callbacks[:yajl_boolean] = @boolean_callback
          callbacks[:yajl_integer] = nil
          callbacks[:yajl_double] = nil
          callbacks[:yajl_number] = @number_callback
          callbacks[:yajl_string] = @string_callback
          callbacks[:yajl_start_map] = @start_map_callback
          callbacks[:yajl_map_key] = @map_key_callback
          callbacks[:yajl_end_map] = @end_map_callback
          callbacks[:yajl_start_array] = @start_array_callback
          callbacks[:yajl_end_array] = @end_array_callback

          @handle = FFI_Yajl.yajl_alloc(@callbacks_memory, nil, nil)
          FFI_Yajl.yajl_config(@handle,
                               :yajl_allow_trailing_garbage,
                               :int,
                               1)
        end

        def finalize_handle
          @callbacks_memory = nil
          FFI_Yajl.yajl_free(@handle)
          @handle = nil
        end
      end
    end
  end
end
