class TurtleGraphics
  class Turtle

    ORIENTATIONS = { 1 => :left, 2 => :up, 3 => :right, 4 => :down }

    def initialize(rows, columns)
      @rows = rows
      @columns = columns
      @matrix = Array.new(rows) { [0] * columns }
      @orientation = :right
      @position = nil
    end

    def draw(canvas = nil, &block)
      if block_given? then self.instance_eval(&block) end

      if @position == nil then spawn_at(0, 0) end

      if canvas != nil
        if canvas.respond_to?(:ascii_draw)
          canvas.ascii_draw(@matrix)
        elsif canvas.respond_to?(:html_draw)
          canvas.html_draw(@matrix)
        end
      else
        @matrix
      end
    end

    def move
      if @position == nil then spawn_at(0, 0) end
      direction = [0, 0]
      case @orientation
        when :left  then direction[1] = -1
        when :up    then direction[0] = -1
        when :right then direction[1] =  1
        when :down  then direction[0] =  1
      end
      change_position(direction)
    end

    def change_position(direction)
      @position = [(@position[0] + direction[0]) % @rows,
                   (@position[1] + direction[1]) % @columns]
      @matrix[@position[0]][@position[1]] += 1
    end

    def turn_left
      temp = ORIENTATIONS.key(@orientation) - 1
      if temp == 0 then temp = 4 end
      @orientation = ORIENTATIONS[temp]
    end

    def turn_right
      temp = ORIENTATIONS.key(@orientation) + 1
      if temp == 5 then temp = 1 end
      @orientation = ORIENTATIONS[temp]
    end

    def spawn_at(row, column)
      @position = [row, column]
      @matrix[@position[0]][@position[1]] += 1
    end

    def look(orientation)
      @orientation = orientation
    end
  end

  class Canvas
    class ASCII
      def initialize(symbols)
        @symbols = symbols
      end

      def ascii_draw(matrix)
        max_number = matrix.map(&:max).max

        matrix.map do |row|
          row.map do |steps|
            symbol_for_step_count(steps, max_number)
          end.join('')
        end.join("\n")
      end

      private

      def symbol_for_step_count(steps, maximum_steps)
        intensity = steps.to_f / maximum_steps
        symbol_index = (intensity * (@symbols.size - 1)).ceil

        @symbols[symbol_index]
      end
    end

    class HTML
      TEMPLATE = <<-TEMPLATE.freeze
        <!DOCTYPE html>
        <html>
        <head>
          <title>Turtle graphics</title>
          <style>
            table {
              border-spacing: 0;
            }
            tr {
              padding: 0;
            }
            td {
              width: %{size_pixels}px;
              height: %{size_pixels}px;
              background-color: black;
              padding: 0;
            }
          </style>
        </head>
        <body>
          <table>%{rows}</table>
        </body>
        </html>
      TEMPLATE

      def initialize(size_pixels = 3)
        @size_pixels = size_pixels
      end

      def html_draw(canvas)
        maximum_intensity = canvas.map(&:max).max

        TEMPLATE % {
          size_pixels: @size_pixels,
          rows: table_rows(canvas, maximum_intensity.to_f)
        }
      end

      private

      def table_rows(canvas, maximum_intensity)
        canvas.map do |row|
          columns = row.map do |intensity|
            '<td style="opacity: %.2f"></td>' % (intensity / maximum_intensity)
          end

          "<tr>#{columns.join('')}</tr>"
        end.join('')
      end
    end
  end
end
