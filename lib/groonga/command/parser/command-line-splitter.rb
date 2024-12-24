# Copyright (C) 2015-2024  Sutou Kouhei <kou@clear-code.com>
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
require "strscan"

module Groonga
  module Command
    class Parser
      class CommandLineSplitter
        def initialize(command_line)
          @command_line = command_line
        end

        def split
          tokens = []
          scanner = StringScanner.new(@command_line)
          skip_spaces(scanner)
          start_quote = nil
          until scanner.eos?
            if start_quote
              token = +""
              loop do
                chunk = scanner.scan_until(/#{Regexp.escape(start_quote)}/)
                if chunk.nil?
                  token = start_quote + token + scanner.rest
                  scanner.terminate
                  break
                end
                if chunk[-2] == "\\"
                  token << chunk
                else
                  token << chunk.chomp(start_quote)
                  break
                end
              end
              tokens << unescape(token)
              start_quote = nil
              skip_spaces(scanner)
            else
              start_quote = scanner.scan(/['"]/)
              if start_quote.nil?
                tokens << scanner.scan_until(/\S+/)
                skip_spaces(scanner)
              end
            end
          end
          tokens
        end

        private
        def skip_spaces(scanner)
          scanner.scan(/\s+/)
        end

        def unescape(token)
          token.gsub(/\\(.)/) do
            character = $1
            case character
            when "b"
              "\b"
            when "f"
              "\f"
            when "n"
              "\n"
            when "r"
              "\r"
            when "t"
              "\t"
            else
              character
            end
          end
        end
      end
    end
  end
end
