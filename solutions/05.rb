require 'digest/sha1'

class ObjectStore
  def initialize
    @branch_manager = BranchManager.new
  end

  def self.init(&block)
    instance = self.new
    if block_given?
      instance.instance_eval(&block)
    end
    instance
  end

  def add(name, object)
    @current_branch = @branch_manager.get_current_branch

    new_file = File.new(name, object)
    update_file(new_file)
    @current_branch.changes += 1

    OperationResult.new("Added #{new_file.name} to stage.", true, object)
  end

  def commit(message)
    if @branch_manager.get_current_branch.changes == 0
      OperationResult.new("Nothing to commit, working directory clean.", false)
    else
      new_commit = Commit.new(@current_branch.local_all_files,
        message, Time.now)
      @current_branch.commits << new_commit
      @current_branch.global_all_files = @current_branch.local_all_files.clone
      changes = @current_branch.changes
      @current_branch.changes = 0
      OperationResult.new("#{new_commit.message}\n\t#{changes}" +
        " objects changed", true, new_commit)
    end
  end

  def update_file(new_file)
    @current_branch = @branch_manager.get_current_branch

    existing_file = @current_branch.local_all_files.select { |f|
      f.name == new_file.name }
    if existing_file != []
      @current_branch.local_all_files -= existing_file
      @current_branch.local_all_files << new_file
    else
      @current_branch.local_all_files << new_file
    end
  end

  def remove(name)
    @current_branch = @branch_manager.get_current_branch

    old_file = @current_branch.local_all_files.select { |f| f.name == name }
    if old_file != []
      @current_branch.local_all_files -= old_file
      @current_branch.changes += 1
      OperationResult.new("Added #{name} for removal.", true, old_file.
        first.obj)
    else
      OperationResult.new("Object #{name} is not committed.", false)
    end
  end

  def checkout(commit_hash)
    @current_branch = @branch_manager.get_current_branch

    new_head = @current_branch.commits.select { |c| c.hash == commit_hash }
    if new_head != []
      @current_branch.commits = @current_branch.commits[
        0..@current_branch.commits.index(new_head.first)]
      update_branch(new_head.first)
      OperationResult.new("HEAD is now at #{commit_hash}.", true,
        new_head.first)
    else
      OperationResult.new("Commit #{commit_hash} does not exist.", false)
    end
  end

  def update_branch(new_commit)
    @current_branch = @branch_manager.get_current_branch

    @current_branch.global_all_files = new_commit.objects.clone
    @current_branch.local_all_files  = new_commit.objects.clone
  end

  def branch
    @branch_manager
  end

  def log
    if @branch_manager.get_current_branch.commits.size == 0
      OperationResult.new("Branch #{@branch_manager.get_current_branch
        .name} does" + " not have any commits yet.", false)
    else
      message = []
      @branch_manager.get_current_branch.commits.reverse.each do |commit|
        message << "Commit #{commit.hash}\nDate: " +
        "#{commit.date.strftime("%a %b %d %H:%M %Y %z")}" +
        "\n\n\t#{commit.message}"
      end
      message = message.join("\n\n")
      OperationResult.new(message, true)
    end
  end

  def head
    @current_branch = @branch_manager.get_current_branch

    if @current_branch.commits.size == 0
      OperationResult.new("Branch #{@current_branch.name} does" +
        " not have any commits yet.", false)
    else
      OperationResult.new("#{@current_branch.commits[-1].message}", true,
        @current_branch.commits[-1])
    end
  end

  def get(name)
    @current_branch = @branch_manager.get_current_branch

    file = @current_branch.global_all_files.select { |f| f.name == name }
    if file != []
      OperationResult.new("Found object #{name}.", true, file.first.obj)
    else
      OperationResult.new("Object #{name} is not committed.", false)
    end
  end

  class Branch
    attr_accessor :commits
    attr_accessor :global_all_files
    attr_accessor :local_all_files
    attr_accessor :changes
    attr_reader :name

    def initialize(name)
      @name = name
      @commits = []
      @global_all_files = []
      @local_all_files  = []
      @changes = 0
    end
  end

  class BranchManager
    def initialize
      @branches = []
      new_branch = Branch.new("master")
      @branches << new_branch
      @current_branch = new_branch
    end

    def get_current_branch
      @current_branch
    end

    def create(branch_name)
      existing_branch = @branches.select { |b| b.name == branch_name }
      if existing_branch == []
        new_branch = Branch.new(branch_name)
        new_branch.commits = @current_branch.commits.clone
        new_branch.global_all_files = @current_branch.global_all_files.clone
        new_branch.local_all_files = @current_branch.local_all_files.clone
        @branches << new_branch
        OperationResult.new("Created branch #{branch_name}.", true)
      else
        OperationResult.new("Branch #{branch_name} already exists.", false)
      end
    end

    def checkout(branch_name)
      existing_branch = @branches.select { |b| b.name == branch_name }
      if existing_branch != []
        @current_branch = existing_branch.first
        OperationResult.new("Switched to branch #{branch_name}.", true)
      else
        OperationResult.new("Branch #{branch_name} does not exist.", false)
      end
    end

    def remove(branch_name)
      old_branch = @branches.select { |b| b.name == branch_name }

      if @current_branch.name == branch_name
        OperationResult.new("Cannot remove current branch.", false)
      elsif old_branch != []
        @branches -= old_branch
        OperationResult.new("Removed branch #{branch_name}.", true)
      else
        OperationResult.new("Branch #{branch_name} does not exist.", false)
      end
    end

    def list
      message = []
      @branches.sort_by { |b| b.name }.each do |branch|
        if branch == @current_branch
          message << "* #{branch.name}"
        else
          message << "  #{branch.name}"
        end
      end
      message = message.join("\n")
      OperationResult.new(message, true)
    end
  end

  class Commit
    attr_reader :message, :hash, :date
    attr_accessor :objects

    def initialize(files, message, date)
      @objects = files.clone
      @message = message
      @date = date
      @hash = Digest::SHA1.hexdigest(
        @date.strftime("%a %b %d %H:%M %Y %z") + @message)
    end
  end

  class OperationResult
    attr_reader :message, :result

    def initialize(message, state, result = nil)
      @message = message
      @state = state
      @result = result
    end

    def success?
      @state ? true : false
    end

    def error?
      @state ? false : true
    end
  end

  class File < Struct.new(:name, :obj)
    def to_s
    "#{name.to_s} - #{obj.to_s}"
    end
  end
end
