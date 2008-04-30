
class NetworkThroughput < Scout::Plugin
  def run
    report = {}
    new_memory = {}

    lines = IO.readlines('/proc/net/dev')[2..-1]

    lines.each do |line|
      iface, rest = line.split(':', 2).collect { |e| e.strip }
      next unless iface =~ /eth/
      cols = rest.split(/\s+/)

      in_bytes, in_packets, out_bytes, out_packets = cols.values_at(0, 1, 8, 9).collect { |i| i.to_i }

      new_memory[iface] = {
        :sample_at => Time.now.to_i,
        :in_bytes => in_bytes,
        :in_packets => in_packets,
        :out_bytes => out_bytes,
        :out_packets => out_packets
      }

      if @memory[iface]
        differences = calculate_difference(@memory[iface], new_memory[iface])
        differences.each do |key, value|
          report["#{iface}_#{key}_per_second"] = value
        end
      end
    end

    report = nil if report.empty?
    { :report => report, :memory => new_memory }
  rescue Exception => e
    { :error => "#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}" }
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
