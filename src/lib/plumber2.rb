class ProjectsPlumber

  attr_reader :dirs

  def initialize(settings)

    # expecting to find here
    #   @settings.path
    #   @settings.storage_dir
    #   @settings.working_dir
    #   @settings.archive_dir
    #   @settings.template_file
    #   @settings.silent = false

    @settings = settings
    @dirs = {}
    @dirs[:storage] = File.join @settings.path, @settings.storage_dir
    @dirs[:working] = File.join @dirs[:storage], @settings.working_dir
    @dirs[:archive] = File.join @dirs[:storage], @settings.archive_dir       

    @template_path  = File.join @settings.path, @settings.template_file
    @dirs[:template] = @template_path

  end

  ##
  # *wrapper* for puts()
  # depends on @settings.silent = true|false

  def logs message, force = false
    puts "       #{__FILE__} : #{message}" unless @settings.silent and not force
  end

  ##
  # Checks the existens of one of the three basic dirs.
  # dir can be either :storage, :working or :archive
  def check_dir(dir)
    return true if File.exists? "#{@dirs[dir]}"
    false
  end

  ##
  # create a dir
  # dir can be either :storage, :working or :archive
  def create_dir(dir)
    unless check_dir(dir)
      if dir == :storage or check_dir :storage
        FileUtils.mkdir "#{@dirs[dir]}"
        logs "Created \"#{dir.to_s}\" Directory (#{@dirs[dir]})"
        return true
      end
    end
    false
  end
 
  ##
  # Path to project folder
  # If the folder exists
  # dir can be :working or :archive 
  #
  # TODO untested for archives
  def get_project_folder( name, dir=:working, year='' )
    year = year.to_s
    target = File.join @dirs[dir], name if dir == :working
    target = File.join @dirs[dir], year, name if dir == :archive
    return target if File.exists? target
    false
  end

  
  ##
  # creates new project_dir and project_file
  def _new_project_folder(name)

    unless check_dir(:working)
      logs(File.exists? @dirs[:working])
      logs "missing working directory!"
      return false
    end

    #  check of existing project with the same name
    folder = get_project_folder(name, :working)
    unless folder
      FileUtils.mkdir File.join @dirs[:working], name
      return get_project_folder(name, :working)
    else
      logs "#{folder} already exists"
      return false
    end
  end


  ##
  # creates new project_dir and project_file
  # returns path to project_file
  def new_project(name)
    name.strip!
    name.sub!(/^\./,'') # removes hidden_file_dot '.' from the begging
    name.gsub!(/\//,'_') 
    name.gsub!(/\//,'_') 

    # copy template_file to project_dir
    folder = _new_project_folder(name)
    if folder
      target = File.join folder, name+".yml"

      FileUtils.cp @dirs[:template], target
      return target
    else
      return false
    end
  end



  ##
  # path to project file
  # there may only be one .yml file per project folder
  #
  # untested
  def get_project_file_path(name, dir=:working)
    if get_project_folder name
      files = Dir.glob File.join get_project_folder(name), "*.yml"
      fail "ambiguous amount of yml files (#{name})" if files.length != 1
      return files[0]
    end
    return false
  end








  ##
  # turn index or name into path
  #
  # untested
  def pick_project input, dir = :working
  end



  ##
  # list projects
  def list_projects(dir = :working)
    return unless check_dir(dir)
    #TODO FIXME XXX
  end

  ##
  #  Move to archive directory
  #  @name 
  def archive_project(name, year = Date.today.year, prefix = '')
    year_folder = File.join @dirs[:archive], year.to_s
    FileUtils.mkdir year_folder unless File.exists? year_folder

    project_folder = get_project_folder name, :working
    target = File.join year_folder, name.prepend(prefix)

    return false unless project_folder

    logs "moving: #{project_folder} to #{target}" if target and project_folder
    FileUtils.mv project_folder, target
    return target
  end

  ##
  #  Move to archive directory
  def unarchive_project(name, year = Date.today.year, prefix = '')
    name.strip!
    return false unless name.start_with? prefix

    cleaned_name = name.deprefix(prefix)
    source = get_project_folder name, :archive, year

    target = File.join @dirs[:working], cleaned_name

    logs "moving #{source} to #{target}"
    return false unless source

    unless get_project_folder cleaned_name
      FileUtils.mv source, target
      return true
    else
      return false
    end

  end



end

class String
  def last
    self.scan(/.$/)[0]
  end
  def deprefix(prefix)
    self.partition(prefix)[2]
  end
end
