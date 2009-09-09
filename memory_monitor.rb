# 
# Created by Eric Lindvall <eric@5stops.com>
#

class MemoryMonitor < Scout::Plugin
  def build_report
    unless File.exists?('/proc/meminfo')
      return error(%Q(Unable to find /proc/meminfo. Please ensure your operationg system supports procfs:
                       http://en.wikipedia.org/wiki/Procfs))
    end

    mem_total = mem_info['MemTotal'] / 1024
    mem_free  = (mem_info['MemFree'] + mem_info['Buffers'] + mem_info['Cached']) / 1024
    mem_used  = mem_total - mem_free
    mem_percent_used = (mem_used / mem_total.to_f * 100).to_i

    swap_total = mem_info['SwapTotal'] / 1024
    swap_free  = mem_info['SwapFree'] / 1024
    swap_used  = swap_total - swap_free
    swap_percent_used = (swap_used / swap_total.to_f * 100).to_i

    report('Memory Total'  => mem_total)
    report('Memory Used'   => mem_used)
    report('% Memory Used' => mem_percent_used)

    report('Swap Total'    => swap_total)
    report('Swap Used'     => swap_used)
    report('% Swap Used'   => swap_percent_used)

    if vmstat?
      counter('Page-ins/sec',    vmstat['pgpgin'],  :per => :second, :round => true)
      counter('Page-outs/sec',   vmstat['pgpgout'], :per => :second, :round => true)
      counter('Page Faults/sec', vmstat['pgfault'], :per => :second, :round => true)
    end
  rescue Exception => e
    error("An error occurred profiling the memory:\n\n#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
  end

  def mem_info?
    File.exists?('/proc/meminfo')
  end

  def mem_info
    @mem_info ||= begin
      hash = {}
      IO.foreach('/proc/meminfo') do |line|
        _, key, value = *line.match(/^(\w+):\s+(\d+)/)
        hash[key] = value.to_i
      end
      hash
    end
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
      last_time, last_value = data.values_at('time', 'value')
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

