# Maps game_type strings → engine class.
# Add a new game: Games::Registry.register("strength", Games::StrengthEngine)
module Games
  module Registry
    @engines = {}

    def self.register(game_type, engine_class)
      @engines[game_type.to_s] = engine_class
    end

    def self.engine_for(game_type)
      @engines.fetch(game_type.to_s) { raise ArgumentError, "Unknown game type: #{game_type}" }
    end

    def self.game_types
      @engines.keys
    end
  end
end
