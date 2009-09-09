
module ScoutCounter
  private
  def counter(*args)
    metrics = {}
    # divide Hash and non-Hash arguments
    hashes, other = args.partition { |value| value.is_a? Hash }
    # merge all Hash arguments into the Mission memory
    hashes.each do |hash|
      metrics.merge!(hash)
    end

    metrics.merge!(Hash[*other])

    current_time = Time.now

    metrics.each do |(name, value)|
      if data = memory(name) && data.is_a?(Hash)
        last_time, last_value = data.values_at(:time, :value)
        elapsed_seconds       = last_time - current_time

        # We won't log it if the value has wrapped or enough time hasn't
        # elapsed
        if value >= last_value && elapsed_seconds >= 1
          result = value - last_value

          report(name => result / elapsed_seconds.to_f)
        end
      end

      remember(name => { :time => current_time, :value => value })
    end
  end
end
