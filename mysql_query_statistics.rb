# 
# Created by Eric Lindvall <eric@5stops.com>
#

require 'set'
require File.dirname(__FILE__) + '/scout_counter'


class MysqlQueryStatistics < Scout::Plugin
  include ScoutCounter

  ENTRIES = %w(Com_insert Com_select Com_update Com_delete).to_set

  def build_report
    begin
      require 'mysql'
    rescue LoadError => e
      error("Unable to find a mysql library. Please install the library to use this plugin")
    end

    user = @options['user'] || 'root'
    password, host, port, socket = @options.values_at(*%w(password host port socket)).collect { |v| v == '' ? nil : v }

    mysql  = Mysql.connect(host, user, password, nil, port, socket)
    result = mysql.query('SHOW /*!50002 GLOBAL */ STATUS')

    rows = []
    total = 0
    result.each do |row| 
      rows << row if ENTRIES.include?(row.first)

      total += row.last.to_i if row.first[0..3] == 'Com_'
    end
    result.free

    rows.each do |row|
      name = row.first[/_(.*)$/, 1]
      counter(name => row.last.to_i)
    end

    counter('total' => total)
  rescue Exception => e
    error("An error occurred profiling mysql:\n\n#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
  end
end

