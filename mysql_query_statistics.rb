# 
# Created by Eric Lindvall <eric@5stops.com>
#

require 'set'

class MysqlQueryStatistics < Scout::Plugin
  ENTRIES = %w(Com_insert Com_select Com_update Com_delete).to_set

  def build_report
    begin
      require 'mysql'
    rescue LoadError => e
      return error("Unable to find a mysql library. Please install the library to use this plugin")
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
      counter(name, row.last.to_i, :round => true, :per => :second)
    end

    counter('total', total, :round => true, :per => :second)
  rescue Exception => e
    error("An error occurred profiling mysql:\n\n#{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}")
  end

  private
  # Would be nice to be part of scout internals
  def counter(name, value, options = {})
    current_time = Time.now

    if data = memory(name)
      last_time, last_value = data.values_at('time', 'value')

      # Deal with bad values
      if last_time && last_value
        elapsed_seconds = current_time - last_time

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
    end

    remember(name => { :time => current_time, :value => value })
  end
end
