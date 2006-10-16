module Debugger
  class Command # :nodoc:
    class << self
      def commands
        @commands ||= []
      end
      
      DEF_OPTIONS = {
        :event => true, 
        :control => false, 
        :always_run => false,
        :unknown => false,
      }
      
      def inherited(klass)
        DEF_OPTIONS.each do |o, v|
          klass.options[o] = v if klass.options[o].nil?
        end
        commands << klass
      end

      def load_commands
        dir = File.dirname(__FILE__)
        Dir[File.join(dir, 'commands', '*')].each do |file|
          require file
        end
      end
      
      def method_missing(meth, *args, &block)
        if meth.to_s =~ /^(.+?)=$/
          @options[$1.intern] = args.first
        else
          if @options.has_key?(meth)
            @options[meth]
          else
            super
          end
        end
      end
      
      def options
        @options ||= {}
      end
    end
    
    def initialize(state, printer)
      @state, @printer = state, printer
    end

    def match(input)
      @match = regexp.match(input)
    end

    protected
    
    def method_missing(meth, *args, &block)
      if @printer.respond_to? meth
        @printer.send meth, *args, &block
      else
        super
      end
    end

    def print(*args)
      @state.print(*args)
    end

    def confirm(msg)
      @state.confirm(msg) == 'y'
    end

    def debug_eval(str)
      begin
        val = eval(str, @state.binding)
      rescue StandardError, ScriptError => e
        @printer.print_exception(e, @state.binding)
        throw :debug_error
      end
    end

    def debug_silent_eval(str)
      begin
        eval(str, @state.binding)
      rescue StandardError, ScriptError
        nil
      end
    end

    def line_at(file, line)
      Debugger.line_at(file, line)
    end

    def get_context(thnum)
      Debugger.contexts.find{|c| c.thnum == thnum}
    end  
  end
  
  Command.load_commands
end