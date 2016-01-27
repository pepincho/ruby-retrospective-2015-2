module Helpers
  def calculate_cell(cell)
    if cell =~ /=([-+]?[0-9])/   then return calculate_number(cell) end
    if cell =~ /=([A-Z])([0-9])/ then    calculate_other_cell(cell) end
  end

  def calculate_number(cell)
    cell[1..cell.size]
  end

  def calculate_other_cell(cell)
    row, column = get_row_col_index(cell[1..cell.size])
    validate_cell_index(row, column, @sheet[row - 1][column - 1])
    calculate_cell(@sheet[row - 1][column - 1])
  end

  def validate_cell_index(row, column, cell_index)
    raise Spreadsheet::Error.new("Invalid cell index '#{cell_index}'") if
    row == 0 or column == 0

    raise Spreadsheet::Error.new("Cell '#{cell_index}' does not exist") if
    row > @sheet.size or column > @sheet.first.size
  end

  def format_string(string)
    sheet = []
    string.split(/\n/).each do |v|
      sheet << v.split(/\t| {2,}/).reject { |s| s.empty? }
    end
    sheet.reject { |s| s.empty? }
  end

  def get_row_col_index(cell_index)
    row    = cell_index.split(/[A-Z]/).reject { |s| s.empty? }
    column = cell_index.split(/[0-9]/).reject { |s| s.empty? }

    [row.first.to_i, get_column_index(column.first)]
  end

  def get_column_index(letters = "")
    column = 0
    letters.split("").each do |i|
      if letters.split("").size % 2 == 0 then column *= 26 end
      column += i.ord - "A".ord + 1
    end
    column
  end
end

class Spreadsheet
  include Helpers

  def initialize(string = "")
    @sheet = format_string(string)
  end

  def empty?
    @sheet == [] ? true : false
  end

  def to_s
    result = []
    @sheet.each do |v|
      result << v.join("\t")
    end
    result.join("\n")
  end

  def cell_at(cell_index)
    row, column = get_row_col_index(cell_index)
    validate_cell_index(row, column, cell_index)
    @sheet[row - 1][column - 1]
  end

  def [](cell_index)
    row, column = get_row_col_index(cell_index)
    validate_cell_index(row, column, cell_index)

    calculate_formula(@sheet[row - 1][column - 1])

    @sheet[row - 1][column - 1][0] == '=' ? calculate_cell(
      @sheet[row - 1][column - 1]) : @sheet[row - 1][column - 1]
  end
end

class Spreadsheet::Error < StandardError
end
