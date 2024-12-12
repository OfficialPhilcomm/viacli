require "msgpack"

class PersistentMemory
  attr_reader :name, :state

  def initialize(name, initial_state = nil)
    @name = name

    if File.exist?(file_location)
      @state = MessagePack.unpack(File.binread(file_location))
    else
      @state = initial_state
      write_state
    end
  end

  def state=(new_state)
    @state = new_state
    write_state
  end

  private

  def write_state
    File.binwrite(file_location, @state.to_msgpack)
  end

  def file_location
    File.join(Dir.home, ".local/share/viacli/#{name}.mem")
  end
end

Dir.mkdir(File.join(Dir.home, ".local/")) if !Dir.exist?(File.join(Dir.home, ".local/"))
Dir.mkdir(File.join(Dir.home, ".local/share")) if !Dir.exist?(File.join(Dir.home, ".local/share"))
Dir.mkdir(File.join(Dir.home, ".local/share/viacli")) if !Dir.exist?(File.join(Dir.home, ".local/share/viacli"))
