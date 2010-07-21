require 'mirah'
module Duby
  class PathArray < Array
    def <<(value)
      super(File.expand_path(value))
    end
  end

  def self.source_path
    source_paths[0] ||= File.expand_path('.')
  end

  def self.source_paths
    @source_paths ||= PathArray.new
  end

  def self.source_path=(path)
    source_paths[0] = File.expand_path(path)
  end

  def self.dest_paths
    @dest_paths ||= PathArray.new
  end

  def self.dest_path
    dest_paths[0] ||= File.expand_path('.')
  end

  def self.dest_path=(path)
    dest_paths[0] = File.expand_path(path)
  end

  def self.find_dest(path)
    expanded = File.expand_path(path)
    dest_paths.each do |destdir|
      if expanded =~ /^#{destdir}\//
        return destdir
      end
    end
  end

  def self.find_source(path)
    expanded = File.expand_path(path)
    source_paths.each do |sourcedir|
      if expanded =~ /^#{sourcedir}\//
        return sourcedir
      end
    end
  end

  def self.dest_to_source_path(target_path)
    destdir = find_dest(target_path)
    path = File.expand_path(target_path).sub(/^#{destdir}\//, '')
    path.sub!(/\.(java|class)$/, '')
    snake_case = File.basename(path).gsub(/[A-Z]/, '_\0').sub(/_/, '').downcase
    snake_case = "#{File.dirname(path)}/#{snake_case}"
    source_paths.each do |source_path|
      ["mirah", "duby"].each do |suffix|
        filename = "#{source_path}/#{path}.#{suffix}"
        return filename if File.exist?(filename)
        filename = "#{source_path}/#{snake_case}.#{suffix}"
        return filename if File.exist?(filename)
      end
    end
    # No source file exists. Just go with the first source path and .mirah
    return "#{self.source_path}/#{path}.mirah"
  end

  def self.compiler_options
    @compiler_options ||= []
  end

  def self.compiler_options=(args)
    @compiler_options = args
  end
end

def mirahc(*files)
  if files[-1].kind_of?(Hash)
    options = files.pop
  else
    options = {}
  end
  source_dir = options.fetch(:dir, Duby.source_path)
  dest = File.expand_path(options.fetch(:dest, Duby.dest_path))
  files = files.map {|f| f.sub(/^#{source_dir}\//, '')}
  flags = options.fetch(:options, Duby.compiler_options)
  args = ['-d', dest, *flags] + files
  chdir(source_dir) do
    puts "mirahc #{args.join ' '}"
    Duby.compile(*args)
    Duby.reset
  end
end

rule '.java' => [proc {|n| Duby.dest_to_source_path(n)}] do |t|
  mirahc(t.source,
         :dir=>Duby.find_source(t.source),
         :dest=>Duby.find_dest(t.name),
         :options=>['-java'])
end

rule '.class' => [proc {|n| Duby.dest_to_source_path(n)}] do |t|
  mirahc(t.source,
         :dir=>Duby.find_source(t.source),
         :dest=>Duby.find_dest(t.name))
end
