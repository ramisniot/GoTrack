#mimics the Rails.cache.cleanup in 3.2.15!
DIR_FORMATTER = "%03X"
FILENAME_MAX_SIZE = 228
EXCLUDED_DIRS = ['.', '..'].freeze

namespace :numerex do
  desc 'Cleanup the expired cache entries'
  task cache_cleanup: :environment do
    search_dir(Rails.cache.cache_path) do |fname|
      key = file_path_key(fname)
      entry = read_entry(key)
      delete_entry(key) if entry && entry.expired?
    end
  end
end

def read_entry(key)
  file_name = key_file_path(key)
  if File.exist?(file_name)
    File.open(file_name) { |f| Marshal.load(f) }
  end
rescue => e
  logger.error("FileStoreError (#{e}): #{e.message}") if logger
  nil
end

def search_dir(dir, &callback)
  return if !File.exist?(dir)
  Dir.foreach(dir) do |d|
    next if EXCLUDED_DIRS.include?(d)
    name = File.join(dir, d)
    if File.directory?(name)
      search_dir(name, &callback)
    else
      callback.call name
    end
  end
end

def delete_entry(key)
  file_name = key_file_path(key)
  if File.exist?(file_name)
    begin
      File.delete(file_name)
      delete_empty_directories(File.dirname(file_name))
      true
    rescue => e
      # Just in case the error was caused by another process deleting the file first.
      raise e if File.exist?(file_name)
      false
    end
  end
end

# Delete empty directories in the cache.
def delete_empty_directories(dir)
  return if File.realpath(dir) == File.realpath(Rails.cache.cache_path)
  if Dir.entries(dir).reject { |f| EXCLUDED_DIRS.include?(f) }.empty?
    Dir.delete(dir) rescue nil
    delete_empty_directories(File.dirname(dir))
  end
end

# Translate a file path into a key.
def file_path_key(path)
  fname = path[Rails.cache.cache_path.to_s.size..-1].split(File::SEPARATOR, 4).last
  URI.decode_www_form_component(fname, Encoding::UTF_8)
end

# Translate a key into a file path.
def key_file_path(key)
  fname = URI.encode_www_form_component(key)
  hash = Zlib.adler32(fname)
  hash, dir_1 = hash.divmod(0x1000)
  dir_2 = hash.modulo(0x1000)
  fname_paths = []

  # Make sure file name doesn't exceed file system limits.
  loop do
    fname_paths << fname[0, FILENAME_MAX_SIZE]
    fname = fname[FILENAME_MAX_SIZE..-1]
    break if fname.blank?
  end

  File.join(Rails.cache.cache_path, DIR_FORMATTER % dir_1, DIR_FORMATTER % dir_2, *fname_paths)
end
