# Simulation is ALLOWED by default in the test env. Tag an example/group with
# `:simulation_not_allowed` to run it as if the environment forbids simulation.
# Simulated requests are made by sending `sim_headers` (X-Simulation: on).
module SimulationHelpers
  def sim_headers(extra = {}) = { Simulation::HEADER => "on" }.merge(extra)
end

RSpec.configure do |config|
  config.include SimulationHelpers

  config.around(:each) do |example|
    x = Rails.application.config.x
    prev = [x.simulation_allowed, x.simulation_collection]
    x.simulation_allowed    = !example.metadata[:simulation_not_allowed]
    x.simulation_collection = "cpigs-collection-879234287"
    example.run
  ensure
    x.simulation_allowed, x.simulation_collection = prev
    Current.reset
  end
end
