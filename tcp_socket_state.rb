# 
# Created by Eric Lindvall <eric@sevenscale.com>
#

class TcpSocketState < Scout::Plugin
  def build_report
    socket_states = Hash.new { |h,k| h[k] = 0 }

    IO.popen("netstat -a -n -t") do |io|
      io.each do |line|
        next unless m = line.match(/^tcp.*?(\w+)\s*$/)
        socket_states[m[1]] += 1
      end
    end

    report socket_states
  end
end
