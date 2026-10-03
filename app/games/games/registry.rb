# Maps game_type strings → engine class.
# Add a new game: Games::Registry.register("strength", Games::StrengthEngine)
module Games
  module Registry
    @engines = {}

    def self.register(game_type, engine_class)
      @engines[game_type.to_s] = engine_class
    end

    def self.engine_for(game_type)
      load_engines
      @engines.fetch(game_type.to_s) { raise ArgumentError, "Unknown game type: #{game_type}" }
    end

    def self.game_types
      load_engines
      @engines.keys
    end

    # Engines register themselves via a side-effect at the bottom of their file.
    # Nothing in a request path references them directly, so Zeitwerk never loads
    # them on its own — force the load on first use, at request time (when the
    # autoloader is ready). Doing this in an initializer breaks boot.
    def self.load_engines
      return if @engines_loaded
      @engines_loaded = true
      Dir[File.expand_path("*_engine.rb", __dir__)].sort.each { |path| require path }
    end
  end
end
