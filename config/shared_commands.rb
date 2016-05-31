# The requested command is passed in here as @command
case @command

when "link:listen"
  Origen.target.load!
  OrigenLink::Listener.run!
  # Important to exit when a command has been fulfilled or else Origen core will try and execute it
  exit 0


# Always leave an else clause to allow control to fall back through to the Origen command handler.
# You probably want to also add the command details to the help shown via 'origen -h',
# you can do this bb adding the required text to @plugin_commands before handing control back to
# Origen.
else
  @plugin_commands << <<-EOT
 link:listen     Listen for OrigenLink requests over http (from a GUI)
  EOT

end
