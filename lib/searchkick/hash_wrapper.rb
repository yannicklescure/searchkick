module Searchkick
  class HashWrapper
    def initialize(data)
      @data = data
    end

    def method_missing(m, *args, &block)
      if @data.key?(m.to_s)
        raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0)" if args.any?
        @data[m.to_s]
      else
        super
      end
    end

    def respond_to?(m, include_private = false)
      @data.key?(m.to_s) || super
    end

    def to_h
      @data
    end

    def inspect
      str = @data.map { |k, v| "#{k}=#{v.inspect}" }.join(" ")
      "#<Searchkick::HashWrapper #{str}>"
    end
  end
end
