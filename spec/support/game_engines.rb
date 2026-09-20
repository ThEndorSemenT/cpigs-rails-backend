# Force-register game engines so Games::Registry.game_types is populated.
# Zeitwerk lazily autoloads — without an explicit reference, LogicEngine's
# Registry.register call at file bottom never fires during tests.
require_relative "../../app/games/games/registry"
require_relative "../../app/games/games/base_engine"
require_relative "../../app/games/games/logic_engine"

# Register a second dummy engine so specs can test different game_type routing.
class Games::StubEngine < Games::BaseEngine
  def valid_move?(_player, _move_type, _payload) = true
  def all_moves_submitted? = true
  def resolve! = { winner: player1, loser: player2, draw: false }
  def cpu_moves = []
end
Games::Registry.register("strength", Games::StubEngine)
