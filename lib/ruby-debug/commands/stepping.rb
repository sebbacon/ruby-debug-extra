module Debugger
  class NextCommand < Command # :nodoc:
    def regexp
      /^\s*n(?:ext)?(?:\s+(\d+))?$/
    end

    def execute
      steps = @match[1] ? @match[1].to_i : 1
      @state.context.step_over steps, @state.context.frames.size - @state.frame_pos
      @state.proceed
    end

    class << self
      def help_command
        'next'
      end

      def help(cmd)
        %{
          n[ext][ nnn]\tgo over one line or till line nnn
        }
      end
    end
  end

  class StepCommand < Command # :nodoc:
    def regexp
      /^\s*s(?:tep)?(?:\s+(\d+))?$/
    end

    def execute
      @state.context.stop_next = @match[1] ? @match[1].to_i : 1
      @state.proceed
    end

    class << self
      def help_command
        'step'
      end

      def help(cmd)
        %{
          s[tep][ nnn]\tstep (into methods) one line or till line nnn
        }
      end
    end
  end

  class FinishCommand < Command # :nodoc:
    def regexp
      /^\s*fin(?:ish)?$/
    end

    def execute
      if @state.frame_pos == @state.context.frames.size
        print "\"finish\" not meaningful in the outermost frame.\n"
      else
        @state.context.stop_frame = @state.context.frames.size - @state.frame_pos
        @state.frame_pos = 0
        @state.proceed
      end
    end

    class << self
      def help_command
        'finish'
      end

      def help(cmd)
        %{
          fin[ish]\treturn to outer frame
        }
      end
    end
  end

  class ContinueCommand < Command # :nodoc:
    def regexp
      /^\s*c(?:ont)?$|^\s*r(?:un)?$/
    end

    def execute
      @state.proceed
    end

    class << self
      def help_command
        %w|cont run|
      end

      def help(cmd)
        if cmd == 'cont'
          %{
            c[ont]\trun until program ends or hit breakpoint
          }
        else
          %{
            r[un]\talias for cont
          }
        end
      end
    end
  end
end