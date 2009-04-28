require 'socket'
module RubyAMP
  class RemoteDebugger
    RUN_FILE = "/tmp/set_breakpoint.rb"
  
    class << self
      attr_reader :not_running
      def socket(retries=1)
        return @socket if @socket
        tryCount = 0
        return puts("not running") if @not_running

        begin
          @socket = TCPSocket.new('localhost', 8990)
        rescue Errno::ECONNREFUSED
          sleep(0.10) and retry if (tryCount+=1) < retries

          @not_running = true
        end
      end

      def connected?
        @socket ? true : false
      end

      def disconnect
        if connected?
          socket.close
        end
        @not_running = nil
        @socket = nil
        true
      end

      def connect(retries = 1, &block)
        d = new(retries)
        if connected?
          yield d
        else
          print "Debugger is not running."
        end
        disconnect
      end
    
      def prepare_debug_wrapper(commands)
        # create a file that will set our breakpoint for us
        File.open(RUN_FILE, 'wb')  do |f|
          f.puts <<-EOF
            require #{File.join(RubyAMP.plugin_root, '/ext/debugger_extension.rb').inspect}
            Debugger.start
            Debugger.settings[:autoeval]=1
            Debugger.settings[:autolist]=1
            Debugger.add_breakpoint #{ENV['TM_FILEPATH'].to_s.inspect}, #{ENV['TM_LINE_NUMBER']}

            Debugger.wait_for_connection
            #{commands}
          EOF
        end
        RUN_FILE
      end
    end
  
    def initialize(retries = 1)
      socket(retries)
    end
  
    def socket(retries = 1); self.class.socket(retries) end
    def connected?; self.class.connected? end
  
    def send_command(cmd, msg = nil)
      return if self.class.not_running
      begin
        @first_output ||= socket.gets
        socket.puts cmd
        puts msg if msg
      rescue Exception
        puts "Error: #{$!.class}"
      end
    end

    def read_output
      return if self.class.not_running
      result = ""
      while line = socket.gets
        break if line =~ /^PROMPT/
        result << line
      end
      result
    rescue Exception
      puts "Error: #{$!.class}"
    end
  
    def command(cmd)
      send_command(cmd)
      read_output
    end
  
    def evaluate(cmd, binding = :current, format = :raw)
      command("e require #{File.join(RubyAMP.plugin_root, '/ext/debugger_extension.rb').inspect}")
      o = command("e Debugger.evaluate(#{cmd.inspect}, :#{binding}, :#{format})")
      eval(o).sub(/\n\Z/,'')
    rescue Exception
      o
    end
  
    def current_frame
      evaluate("::Debugger.current_frame", :control)
    end
    
    AUTO_LOAD = {
      :BreakpointCommander  => 'breakpoint_commander.rb',
      :CommanderBase        => 'commander_base.rb',
    }

    def self.const_missing(name)
      @looked_for ||= {}
      raise "Class not found: #{name}" if @looked_for[name]

      return super unless AUTO_LOAD[name]
      @looked_for[name] = true

      require File.join(RubyAMP.lib_root, "remote_debugger", AUTO_LOAD[name])
      const_get(name)
    end
    
    def breakpoint
      @breakpoint ||= BreakpointCommander.new(self)
    end
  end
end

at_exit { RubyAMP::RemoteDebugger.disconnect }
