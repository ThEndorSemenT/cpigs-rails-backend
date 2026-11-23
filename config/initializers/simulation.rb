# Simulation mode flags. Real mode (default) is untouched: everything simulation
# related is gated by Simulation.enabled?.
settings = Rails.application.config_for(:settings)[:simulation] || {}

Rails.application.config.x.simulation_mode =
  ActiveModel::Type::Boolean.new.cast(settings[:enabled]) || false
Rails.application.config.x.simulation_collection =
  settings[:collection].presence || "cpigs-collection-879234287"
