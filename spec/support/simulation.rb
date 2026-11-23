# Tag an example/group with `:simulation` to run it with SIMULATION_MODE on.
RSpec.configure do |config|
  config.around(:each) do |example|
    x = Rails.application.config.x
    prev = [x.simulation_mode, x.simulation_collection]
    x.simulation_mode = example.metadata[:simulation] ? true : false
    x.simulation_collection = "cpigs-collection-879234287"
    example.run
  ensure
    x.simulation_mode, x.simulation_collection = prev
  end
end
