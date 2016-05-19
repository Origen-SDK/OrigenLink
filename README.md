# OrigenLink

Plug-in for Origen to enable live silicon debug from Origen source

Included are source files for the Plug-in:

  * callback_handlers.rb
    * methods to initialize and finalize automatically when a pattern is run

  * capture_support.rb
    * implements capture of vector data when requested, moves actual DUT response into the origen environment

  * configuration_commands.rb
    * methods for defining pin map, pin order, timing

  * server_com.rb
    * methods for interfacing with the server side app

  * vector_based.rb
    * implements the main methods for intercepting vector data from origen and running them

  
Also included are the server side source files intended to run on a [Udoo Neo](http://www.udoo.org/docs-neo/Introduction/Introduction.html) or similar IoT device.  The server is responsible for driving and reading IO's:

  * pin.rb
    * pin class for interacting with 

  * sequencer.rb
    * the brains behind the server app

  * start_link_server
    * located in the bin directory, serves a 2 way TCP interface between the app side plug-in and the server side sequencer