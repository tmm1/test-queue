module TestQueue
  class Stats
    class Suite
      attr_reader :name, :path, :duration, :last_seen_at

      def initialize(name, path, duration, last_seen_at)
        @name = name
        @path = path
        @duration = duration
        @last_seen_at = last_seen_at

        freeze
      end

      def ==(other)
        other &&
          name == other.name &&
          path == other.path &&
          duration == other.duration &&
          last_seen_at == other.last_seen_at
      end
      alias_method :eql?, :==

      def to_h
        { :name => name, :path => path, :duration => duration, :last_seen_at => last_seen_at.to_i }
      end

      def self.from_hash(hash)
        self.new(hash.fetch(:name),
                 hash.fetch(:path),
                 hash.fetch(:duration),
                 Time.at(hash.fetch(:last_seen_at)))
      end
    end

    def initialize(path)
      @path = path
      @suites = {}
      load
    end

    def all_suites
      @suites.values
    end

    def suite(name)
      @suites[name]
    end

    def record_suites(suites)
      suites.each do |suite|
        @suites[suite.name] = suite
      end
    end

    def save
      prune

      File.open(@path, "wb") do |f|
        Marshal.dump(to_h, f)
      end
    end

    private

    CURRENT_VERSION = 2

    def to_h
      suites = @suites.each_value.map(&:to_h)

      { :version => CURRENT_VERSION, :suites => suites }
    end

    def load
      data = begin
               File.open(@path, "rb") { |f| Marshal.load(f) }
             rescue Errno::ENOENT, EOFError, TypeError, ArgumentError
             end
      return unless data && data.is_a?(Hash) && data[:version] == CURRENT_VERSION
      data[:suites].each do |suite_hash|
        suite = Suite.from_hash(suite_hash)
        @suites[suite.name] = suite
      end
    end

    EIGHT_DAYS_S = 8 * 24 * 60 * 60

    def prune
      earliest = Time.now - EIGHT_DAYS_S
      @suites.delete_if do |name, suite|
        suite.last_seen_at < earliest
      end
    end
  end
end
