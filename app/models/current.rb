# Per-request context (reset automatically by Rails between requests).
#   simulation – true when the request asked for simulation (X-Simulation: on)
#                AND Simulation.allowed?. Set once in ApiController.
# Jobs/services must NOT read this: they use GameSession#simulation?.
class Current < ActiveSupport::CurrentAttributes
  attribute :simulation, default: false
end
