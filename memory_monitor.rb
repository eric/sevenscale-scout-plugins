# 
# Created by Eric Lindvall <eric@5stops.com>
#

require File.dirname(__FILE__) + '/scout_counter'

class MemoryMonitor < Scout::Plugin
  include ScoutCounter

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
      counter('Page-ins'    => vmstat['pgpgin'])
      counter('Page-outs'   => vmstat['pgpgout'])
      counter('Page Faults' => vmstat['pgfault'])
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

end

