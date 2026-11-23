# Simulation settings. The only reader of this config is Simulation.allowed? /
# Simulation.collection — do not read these values anywhere else.
settings = Rails.application.config_for(:settings)[:simulation] || {}

Rails.application.config.x.simulation_allowed =
  ActiveModel::Type::Boolean.new.cast(settings[:allowed]) || false
Rails.application.config.x.simulation_collection =
  settings[:collection].presence || "cpigs-collection-879234287"
