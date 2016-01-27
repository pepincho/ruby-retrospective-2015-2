module LazyMode
  def self.create_file(file_name, &block)
    file = LazyMode::File.new(file_name)
    file.instance_eval(&block)
  end
end

class LazyMode::Date
  attr_reader :year, :month, :day

  def initialize(string)
    @representation = string
    @year  = string.split('-')[0].to_i
    @month = string.split('-')[1].to_i
    @day   = string.split('-')[2].to_i
  end

  def to_s
    @representation
  end
end

module LazyMode::NoteOperations
  def status(string)
    @status = string
  end

  def body(string)
    @body = string
  end

  def scheduled(string)
    @scheduled = string
  end
end

class LazyMode::Note
  attr_reader :header, :file_name, :tags
  attr_writer :header, :file_name, :tags

  def initialize(header, *tags, file_name, file)
    @header, @file_name = header, file_name
    @tags = tags
    @status = :topostpone
    @body, @scheduled = "", ""
    @notes = []
    @file = file
  end

  def note(header, *tags, &block)
    note = LazyMode::Note(header, *tags)
    @notes << note
    note.instance_eval(&block)
  end

  def scheduled(string)
    @scheduled = string
  end

  def status(string = nil)
    if string.nil?
      @status
    else
      @status = string
    end
  end

  def body(string = nil)
    if string.nil?
      @body
    else
      @body = string
    end
  end

  def to_s
    "#{@header} - #{@tags} - #{file_name} #{@body}, #{@status}, #{@scheduled}"
  end
end

class LazyMode::File
  attr_reader :name, :notes

  def initialize(file_name)
    @name = file_name
    @notes = []
  end

  def note(header, *tags, &block)
    note = LazyMode::Note.new(header, *tags, @name, self)
    @notes << note
    note.instance_eval(&block)

    self
  end

  def daily_agenda(date)
    LazyMode::DailyAgenda.new(date, @notes)
  end

  def weekly_agenda(date)
  end
end

class LazyMode::DailyAgenda
  def initialize(date, notes)
    @date = date
    @notes = notes
  end

  def notes
  end

  def where(tag: nil, text: nil, status: nil)
  end
end

class LazyMode::WeeklyAgenda
  def initialize(date, notes)
    @date = date
    @notes = notes
  end

  def notes
  end

  def where(tag: nil, text: nil, status: nil)
  end
end
