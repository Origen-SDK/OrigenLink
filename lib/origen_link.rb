require 'origen'
require 'origen_testers'
require 'socket'

module OrigenLink
  # Load all files in the lib directory via a wildcard, if your project becomes
  # large or load order dependencies start to creep in then you may need to
  # start taking control of this manually as described above.
  # Note that there is no problem from requiring a file twice (Ruby will ignore
  # the second require), so if you have a file that must be required up front
  # you can do that one manually and the let the wildcard take care of the rest.
#  Dir.glob("#{File.dirname(__FILE__)}/**/*.rb").sort.each do |file|
#    require file
#  end
  Dir.glob("#{File.dirname(__FILE__)}/origen_link/*.rb").sort.each do |file|
    require file
  end
  
end
