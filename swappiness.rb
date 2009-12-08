# 
# Created by Eric Lindvall <eric@5stops.com>
#

class MemoryMonitor < Scout::Plugin
  def build_report
    if vmstat?
      counter('Swap-ins',    vmstat['pswpin'],  :per => :second, :round => true)
      counter('Swap-outs',   vmstat['pswpout'], :per => :second, :round => true)
      counter('Page-outs',   vmstat['pgpgout'], :per => :second, :round => true)
      counter('Page-ins',    vmstat['pgpgin'],  :per => :second, :round => true)
      counter('Page-outs',   vmstat['pgpgout'], :per => :second, :round => true)
      counter('Page Faults', vmstat['pgfault'], :per => :second, :round => true)
    end
  rescue Exception => e
    error("An error occurred profiling the memory:\n\n#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
  end

  def vmstat?
    File.exists?('/proc/vmstat')
  end

  def vmstat
    @vmstat ||= begin
      hash = {}
      IO.foreach('/proc/vmstat') do |line|
        _, key, value = *line.match(/^(\w+)\s+(\d+)/)
        hash[key] = value.to_i
      end
      hash
    end
  end

  private
  # Would be nice to be part of scout internals
  def counter(name, value, options = {})
    current_time = Time.now

    if data = memory(name)
      last_time, last_value = data[:time], data[:value]
      elapsed_seconds       = current_time - last_time

      # We won't log it if the value has wrapped or enough time hasn't
      # elapsed
      if value >= last_value && elapsed_seconds >= 1
        result = value - last_value

        case options[:per]
        when :second, 'second'
          result = result / elapsed_seconds.to_f
        when :minute, 'minute'
          result = result / elapsed_seconds.to_f / 60.0
        end

        result = result.to_i if options[:round]

        report(name => result)
      end
    end

    remember(name => { :time => current_time, :value => value })
  end
end

