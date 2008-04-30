require 'set'

class MysqlQueryStatistics < Scout::Plugin
  ENTRIES = %w(Com_insert Com_select Com_update Com_delete).to_set

  def run
    begin
      require 'mysql'
    rescue LoadError => e
      return { :error => { :subject => "Unable to gather Mysql query statistics",
        :body => "Unable to find a mysql library. Please install the library to use this plugin" }
      }
    end

    user = @options['user'] || 'root'
    password, host, port, socket = @options.values_at %w(password host port socket)

    now = Time.now
    mysql = Mysql.connect(host, user, password, nil, port, socket)
    result = mysql.query('SHOW /*!50002 GLOBAL */ STATUS')

    rows = []
    result.each do |row| 
      rows << row if ENTRIES.include?(row.first)
    end
    result.free


    report = {}
    rows.each do |row|
      name = row.first[/_(.*)$/, 1]
      report[name] = calculate_counter(now, name, row.last.to_i)
    end

    { :report => report, :memory => @memory }
  end

  private
  def calculate_counter(current_time, name, value)
    result = nil

    if @memory[name] && @memory[name].is_a?(Hash)
      last_time, last_value = @memory[name].values_at(:time, :value)

      # We won't log it if the value has wrapped
      if value >= last_value
        elapsed_seconds = last_time - current_time
        elapsed_seconds = 1 if elapsed_seconds < 1

        result = value - last_value

        if @options['calculate_per_second']
          result = result / elapsed_seconds.to_f
        end
      end
    end

    @memory[name] = { :time => current_time, :value => value }

    result
  end
end

