# 
# Created by Eric Lindvall <eric@5stops.com>
#

class NetworkThroughput < Scout::Plugin
  def build_report
    lines = IO.readlines('/proc/net/dev')[2..-1]

    lines.each do |line|
      iface, rest = line.split(':', 2).collect { |e| e.strip }
      next unless iface =~ /eth/
      cols = rest.split(/\s+/)

      in_bytes, in_packets, out_bytes, out_packets = cols.values_at(0, 1, 8, 9).collect { |i| i.to_i }

      new_data = {
        :sample_at => Time.now.to_i,
        :in_bytes => in_bytes,
        :in_packets => in_packets,
        :out_bytes => out_bytes,
        :out_packets => out_packets
      }

      if old_data = memory(iface)
        differences = calculate_difference(old_data, new_data)
        differences.each do |key, value|
          report("#{iface}_#{key}_per_second" => value)
        end
      end

      remember(iface => new_data)
    end
  rescue Exception => e
    error("#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
  end

  private
  def calculate_difference(first, second)
    first, second = first.dup, second.dup

    elapsed_seconds = second.delete(:sample_at) - first.delete(:sample_at)
    elapsed_seconds = 1 if elapsed_seconds < 1

    result = {}

    second.each do |key, value|
      result[key] = (value - first[key]) / elapsed_seconds
    end

    result
  end
end
