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
    @branch = @branch_manager.branch

    new_file = File.new(name, object)
    update_file(new_file)
    @branch.changes += 1

    OperationResult.new("Added #{new_file.name} to stage.", true, object)
  end

  def commit(message)
    if @branch_manager.branch.changes == 0
      OperationResult.new("Nothing to commit, working directory clean.", false)
    else
      new_commit = Commit.new(@branch.local_all_files,
        message, Time.now)
      @branch.commits << new_commit
      @branch.global_all_files = @branch.local_all_files.clone
      changes = @branch.changes
      @branch.changes = 0
      OperationResult.new("#{new_commit.message}\n\t#{changes}" +
        " objects changed", true, new_commit)
    end
  end

  def update_file(new_file)
    @branch = @branch_manager.branch

    existing_file = @branch.local_all_files.select { |f|
      f.name == new_file.name }
    if existing_file != []
      @branch.local_all_files -= existing_file
      @branch.local_all_files << new_file
    else
      @branch.local_all_files << new_file
    end
  end

  REMOVE = "Added %{name} for removal."

  def remove(name)
    @branch = @branch_manager.branch
    old_file = @branch.local_all_files.select { |f| f.name == name }
    if old_file != []
      @branch.local_all_files -= old_file
      @branch.changes += 1
      OperationResult.new(REMOVE % { name: name }, true, old_file.first.obj)
    else
      OperationResult.new("Object #{name} is not committed.", false)
    end
  end

  CHECKOUT = "HEAD is now at %{hash}."

  def checkout(hash)
    @branch = @branch_manager.branch
    head = @branch.commits.select { |c| c.hash == hash }
    if head != []
      @branch.commits = @branch.commits[0..@branch.commits.index(head.first)]
      update_branch(head.first)
      OperationResult.new(CHECKOUT % { hash: hash }, true, head.first)
    else
      OperationResult.new("Commit #{hash} does not exist.", false)
    end
  end

  def update_branch(new_commit)
    @branch = @branch_manager.branch

    @branch.global_all_files = new_commit.objects.clone
    @branch.local_all_files  = new_commit.objects.clone
  end

  def branch
    @branch_manager
  end

  LOG = "Branch %{name} does not have any commits yet."

  ONE = "Commit #{hash}\nDate: "


  def log
    if @branch_manager.branch.commits.size == 0
      OperationResult.new(LOG % { name: @branch_manager.branch.name
        }, false)
    else
      message = []
      @branch_manager.branch.commits.reverse.each do |commit|
        message << "Commit #{commit.hash}\nDate: " +
        "#{commit.date.strftime("%a %b %d %H:%M %Y %z")}" +
        "\n\n\t#{commit.message}"
      end
      OperationResult.new(message.join("\n\n"), true)
    end
  end

  def head
    @branch = @branch_manager.branch

    if @branch.commits.size == 0
      OperationResult.new("Branch #{@branch.name} does" +
        " not have any commits yet.", false)
    else
      OperationResult.new("#{@branch.commits[-1].message}", true,
        @branch.commits[-1])
    end
  end

  def get(name)
    @branch = @branch_manager.branch

    file = @branch.global_all_files.select { |f| f.name == name }
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
      @branch = new_branch
    end

    def branch
      @branch
    end

    def create(branch_name)
      existing_branch = @branches.select { |b| b.name == branch_name }
      if existing_branch == []
        new_branch = Branch.new(branch_name)
        update_branch(new_branch)
        OperationResult.new("Created branch #{branch_name}.", true)
      else
        OperationResult.new("Branch #{branch_name} already exists.", false)
      end
    end

    def update_branch(new_branch)
      new_branch.commits = @branch.commits.clone
      new_branch.global_all_files = @branch.global_all_files.clone
      new_branch.local_all_files = @branch.local_all_files.clone
      @branches << new_branch
    end

    def checkout(branch_name)
      existing_branch = @branches.select { |b| b.name == branch_name }
      if existing_branch != []
        @branch = existing_branch.first
        OperationResult.new("Switched to branch #{branch_name}.", true)
      else
        OperationResult.new("Branch #{branch_name} does not exist.", false)
      end
    end

    def remove(branch_name)
      old_branch = @branches.select { |b| b.name == branch_name }

      if @branch.name == branch_name
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
        if branch == @branch
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
      @objects = files.map(&:to_s).clone
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
    "#{obj.to_s}"
    end
  end
end
