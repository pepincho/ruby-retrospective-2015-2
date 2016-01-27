class TurtleGraphics
  class Turtle

    ORIENTATIONS = { 1 => :left, 2 => :up, 3 => :right, 4 => :down }

    def initialize(rows, columns)
      @rows = rows
      @columns = columns
      @matrix = Array.new(@rows) { Array.new(@columns) { 0 } }
      @orientation = :right
      @current_position = nil
    end

    def draw(canvas = nil, &block)
      if block_given?
        self.instance_eval(&block)
      end

      if @current_position == nil then spawn_at(0, 0) end

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
      if @current_position == nil then spawn_at(0, 0) end
      direction = [0, 0]
      if @orientation == :left  then direction[1] = -1 end
      if @orientation == :up    then direction[0] = -1 end
      if @orientation == :right then direction[1] =  1 end
      if @orientation == :down  then direction[0] =  1 end
      @current_position = [(@current_position[0] + direction[0]) % @rows,
                           (@current_position[1] + direction[1]) % @columns]
      @matrix[@current_position[0]][@current_position[1]] += 1
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
      @current_position = [row, column]
      @matrix[@current_position[0]][@current_position[1]] += 1
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
        max_number = matrix.flatten.max
        result = []
        matrix.each_with_index do |x, xi|
          temp = ""
          x.each_with_index do |y, yi|
            itensity = y.fdiv(max_number) * (@symbols.size - 1)
            symbol = @symbols[itensity.ceil]
            temp += symbol
          end
          result << temp
        end
        result.join("\n")
      end
    end

    class HTML
      def initialize(size_pixels)
        @size_pixels = size_pixels

        @text = "<!DOCTYPE html><html><head><title>Turtle graphics</title>" +
        "<style>table { border-spacing: 0; } tr { padding: 0; } " +
        "td { width: #{@size_pixels}px; height: #{@size_pixels}px; " +
        "background-color: black; padding: 0; } </style> " +
        "</head> <body> <table>"
      end

      def html_draw(matrix)
        max_number = matrix.flatten.max
        matrix.each_with_index do |x, xi|
          temp = "<tr>"
          x.each_with_index do |y, yi|
            itensity = format('%.2f', y.fdiv(max_number))
            temp += "<td style=\"opacity: #{itensity}\"></td>"
          end
          temp += "</tr>"
          @text += temp
        end
        @text += "</table> </body> </html>"
      end
    end
  end
end
