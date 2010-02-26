require 'duby'
module Duby
  def self.source_path
    @source_path ||= File.expand_path('.')
  end

  def self.source_path=(path)
    @source_path = File.expand_path(path)
  end

  def self.dest_path
    @dest_path ||= File.expand_path('.')
  end

  def self.dest_path=(path)
    @dest_path = File.expand_path(path)
  end

  def self.dest_to_source_path(path)
    source = File.expand_path(path).sub(/\.(?:java|class)/, '.duby')
    source = source.sub(/^#{dest_path}\//, "#{source_path}/")
    down = source[0,1].downcase + source[1,source.size]
    return down if File.exist?(down)
    source
  end

  def self.compiler_options
    @compiler_options ||= []
  end

  def self.compiler_options=(args)
    @compiler_options = args
  end
end

def dubyc(*files)
  if files[-1].kind_of?(Hash)
    options = files.pop
  else
    options = {}
  end
  source_dir = options.fetch(:dir, Duby.source_path)
  dest = options.fetch(:dest, Duby.dest_path)
  files = files.map {|f| f.sub(/^#{source_dir}\//, '')}
  flags = options.fetch(:options, Duby.compiler_options)
  args = ['-d', dest, *flags] + files
  chdir(source_dir) do
    puts $CLASSPATH.inspect
    puts "dubyc #{args.join ' '}"
    Duby.compile(*args)
    Duby.reset
  end
end

rule '.java' => [proc {|n| Duby.dest_to_source_path(n)}] do |t|
  dubyc(t.source, :options=>['-java'])
end

rule '.class' => [proc {|n| Duby.dest_to_source_path(n)}] do |t|
  dubyc(t.source)
end
