module Debugger
  # Mix-in module to assist in command parsing.
  module FrameFunctions # :nodoc:
    def adjust_frame(frame_pos, absolute, context=@state.context)
      @state.frame_pos = 0 if context != @state.context
      if absolute
        if frame_pos < 0
          abs_frame_pos = context.stack_size + frame_pos
        else
          abs_frame_pos = frame_pos
        end
      else
        abs_frame_pos = @state.frame_pos + frame_pos
      end

      if abs_frame_pos >= context.stack_size then
        errmsg "Adjusting would put us beyond the oldest (initial) frame.\n"
        return
      elsif abs_frame_pos < 0 then
        errmsg "Adjusting would put us beyond the newest (innermost) frame.\n"
        return
      end
      if @state.frame_pos != abs_frame_pos then
        @state.previous_line = nil
        @state.frame_pos = abs_frame_pos
      end
      
      @state.file = context.frame_file(@state.frame_pos)
      @state.line = context.frame_line(@state.frame_pos)
      
      print_frame(@state.frame_pos, true)
    end
    
    def get_frame_call(prefix, pos, context)
      id = context.frame_method(pos)
      klass = context.frame_class(pos)
      call_str = ""
      if id
        args = context.frame_args(pos)
        locals = context.frame_locals(pos)
        if Command.settings[:callstyle] != :short && klass
          if Command.settings[:callstyle] == :tracked
            arg_info = context.frame_args_info(pos)
          end
          call_str << "#{klass}." 
        end
        call_str << id.id2name
        if args.any?
          call_str << "("
          args.each_with_index do |name, i|
            case Command.settings[:callstyle] 
            when :short
              call_str += "%s, " % [name]
            when :last
              klass = locals[name].class
              if klass.inspect.size > 20+3
                klass = klass.inspect[0..20]+"..." 
              end
              call_str += "%s#%s, " % [name, klass]
            when :tracked
              if arg_info && arg_info.size > i
                call_str += "#{name}: #{arg_info[i].inspect}, "
              else
                call_str += "%s, " % name
              end
            end
            if call_str.size > self.class.settings[:width] - prefix.size
              # Strip off trailing ', ' if any but add stuff for later trunc
              call_str[-2..-1] = ",...XX"
              break
            end
          end
          call_str[-2..-1] = ")" # Strip off trailing ', ' if any 
        end
      end
      return call_str
    end

    def print_frame(pos, adjust = false, context=@state.context)
      file = context.frame_file(pos)
      line = context.frame_line(pos)
      klass = context.frame_class(pos)

      unless Command.settings[:full_path]
        path_components = file.split(/[\\\/]/)
        if path_components.size > 3
          path_components[0...-3] = '...'
          file = path_components.join(File::ALT_SEPARATOR || File::SEPARATOR)
        end
      end

      frame_num = "#%d " % pos
      call_str = get_frame_call(frame_num, pos, context)
      file_line = "at line %s:%d\n" % [CommandProcessor.canonic_file(file), line]
      print frame_num
      unless call_str.empty?
        print call_str
        print ' '
        if call_str.size + frame_num.size + file_line.size > self.class.settings[:width]
          print "\n       "
        end
      end
      print file_line
      if ENV['EMACS'] && adjust
        fmt = (Debugger.annotate.to_i > 1 ?
               "\032\032source %s:%d\n" : "\032\032%s:%d\n")
        print fmt % [CommandProcessor.canonic_file(file), line]
      end
    end
  end

  # Implements debugger "where" or "backtrace" command
  class WhereCommand < Command
    def regexp
      /^\s*(?:w(?:here)?|bt|backtrace)$/
    end

    def execute
      (0...@state.context.stack_size).each do |idx|
        if idx == @state.frame_pos
          print "--> "
        else
          print "    "
        end
        print_frame(idx)
      end
    end

    class << self
      def help_command
        %w|where backtrace|
      end

      def help(cmd)
        if cmd == 'where'
          %{
            w[here]\tdisplay frames
          }
        else
          %{
            bt|backtrace\t\talias for where
          }
        end
      end
    end
  end

  class UpCommand < Command # :nodoc:
    def regexp
      /^\s* u(?:p)? (?:\s+(.*))?$/x
    end

    def execute
      pos = get_int(@match[1], "Up")
      return unless pos
      adjust_frame(pos, false)
    end

    class << self
      def help_command
        'up'
      end

      def help(cmd)
        %{
          up[count]\tmove to higher frame
        }
      end
    end
  end

  class DownCommand < Command # :nodoc:
    def regexp
      /^\s* down (?:\s+(.*))? .*$/x
    end

    def execute
      pos = get_int(@match[1], "Down")
      return unless pos
      adjust_frame(-pos, false)
    end

    class << self
      def help_command
        'down'
      end

      def help(cmd)
        %{
          down[count]\tmove to lower frame
        }
      end
    end
  end
  
  class FrameCommand < Command # :nodoc:
    def regexp
      / ^\s* 
        f(?:rame)? 
        (?: \s+ (\S+))? \s*
        (?: thread \s+ (.*))? \s*
        $/x
    end

    def execute
      if not @match[1]
        errmsg "Missing a frame number argument.\n"
        return
      else
        pos = get_int(@match[1], "Frame")
        return unless pos
      end
      if @match[2]
        context = parse_thread_num('frame', @match[2])
        unless context
          errmsg "Thread #{@match[2]} doesn't exist.\n"
          return
        end
      else
        context = @state.context
      end
      adjust_frame(pos, true, context)
    end

    class << self
      def help_command
        'frame'
      end

      def help(cmd)
        %{
          f[rame] frame-number [thread thread-number]
          Move the current frame to the specified frame number.

          A negative number indicates position from the other end.  So
          'frame -1' moves to the oldest frame, and 'frame 0' moves to
          the newest frame.

          Without an argument, the command prints the current stack
          frame. Since the current position is redisplayed, it may trigger a
          resyncronization if there is a front end also watching over
          things. 

          If a thread number is given then we set the context for evaluating
          expressions to that frame of that thread. 
        }
      end
    end
  end
end
