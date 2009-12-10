#
# A Scout plugin to collect CPU usage from a system
#
# Created by Eric Lindvall <eric@sevenscale.com>
#

class CpuUsage < Scout::Plugin
  def build_report
    stats = CpuStats.fetch

    if previous = memory(:cpu_stats)
      previous_stats = CpuStats.new(previous)

      report(stats.diff(previous_stats))
    end

    remember(:cpu_stats => stats.to_h)
  rescue Exception => e
    error("Error running plugin: #{e.class}", e.message)
  end

  class CpuStats
    attr_accessor :user, :system, :idle, :iowait

    def self.fetch
      data = File.read("/proc/stat").split(/\n/).collect { |line| line.split }

      if cpu = data.detect { |line| line[0] == 'cpu' }
        user, nice, system, idle, iowait, hardirq, softirq = *cpu[1..-1].collect { |c| c.to_i }

        user   += nice
        system += hardirq + softirq

        CpuStats.new(:user => user, :system => system, :idle => idle, :iowait => iowait)
      end
    end

    def initialize(hash)
      self.user   = hash[:user]
      self.system = hash[:system]
      self.idle   = hash[:idle]
      self.iowait = hash[:iowait]
    end

    def diff(other)
      diff_user   = user - other.user
      diff_system = system - other.system
      diff_idle   = idle - other.idle
      diff_iowait = iowait - other.iowait

      div = diff_user + diff_system + diff_idle + diff_iowait
      divo2 = div / 2

      { 
        :user   => (100.0 * diff_user + divo2) / div,
        :system => (100.0 * diff_system + divo2) / div,
        :idle   => (100.0 * diff_idle + divo2) / div,
        :iowait => (100.0 * diff_iowait + divo2) / div
      }
    end

    def to_h
      { :user => user, :system => system, :idle => idle, :iowait => iowait }
    end
  end
end

