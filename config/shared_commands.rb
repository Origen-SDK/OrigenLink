# The requested command is passed in here as @command
case @command

when "link:listen"
  t = Thread.new do
    OrigenLink::Listener.run!
  end
  Thread.new do
    # Get the current host
    host = `hostname`.strip.downcase
    if Origen.os.windows?
      domain = ''  # Not sure what to do in this case...
    else
      domain = `dnsdomainname`.strip
    end
    port = 20020
    puts ''
    sleep 0.5
    puts
    puts
    puts "*************************************************************"
    puts "Point your OrigenLink app to:  http://#{host}#{domain.empty? ? '' : '.' + domain}:#{port}"
    puts "*************************************************************"
    puts
    puts
  end

  # Fall through to the Origen interactive command to open up a console
  @command = "interactive"

# Always leave an else clause to allow control to fall back through to the Origen command handler.
# You probably want to also add the command details to the help shown via 'origen -h',
# you can do this bb adding the required text to @plugin_commands before handing control back to
# Origen.
else
  @plugin_commands << <<-EOT
 link:listen     Open a console and listen for OrigenLink requests over http (i.e. from a GUI)
  EOT

end
