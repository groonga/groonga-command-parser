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

require "groonga/command"

module Groonga
  module Command
    class Parser
      class Error < Command::Error
        attr_reader :reason, :location
        def initialize(reason, before, after)
          @reason = reason
          @location = compute_location(before, after)
          super("#{@reason}:\n#{@location}")
        end

        private
        def compute_location(before, after)
          location = ""
          if before[-1] == ?\n
            location << before
            location << after
            location << "^"
          elsif after[0] == ?\n
            location << before
            location << "\n"
            location << " " * before.bytesize + "^"
            location << after
          else
            before_lines = before.lines
            after_lines = after.lines
            last_before_line = before_lines.last
            if last_before_line
              error_offset = last_before_line.bytesize
            else
              error_offset = 0
            end
            before_lines.each do |before_line|
              location << before_line
            end
            location << after_lines.first
            location << " " * error_offset + "^\n"
            after_lines[1..-1].each do |after_line|
              location << after_line
            end
          end
          location
        end
      end
    end
  end
end
