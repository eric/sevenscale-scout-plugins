# 
# Simple plugin to generate mysqltuner.pl summary
#
# Created by Eric Lindvall <eric@sevenscale.com>
#

class MysqltunerReport < Scout::Plugin
  def build_report
    cmd = "curl -s http://mysqltuner.pl/mysqltuner.pl | perl - --nocolor"
    data = `#{cmd} 2>&1`
    unless $?.success?
      return error "Could not get data from command: #{cmd}", "Error: #{data}"
    end   

    summary(:command => 'mysqltuner results', :output => data)
  end
end
