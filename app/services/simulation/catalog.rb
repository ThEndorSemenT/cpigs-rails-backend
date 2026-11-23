module Simulation
  # Reads config/simulation/collections/<name>.yml. No chain calls.
  # Entry: { token_id, name, image, burn_power }
  class Catalog
    class UnknownCollection < StandardError; end

    DIR = Rails.root.join("config/simulation/collections")

    def self.entries(collection)
      name = collection.to_s
      raise UnknownCollection, "Invalid collection name: #{name.inspect}" unless name.match?(/\A[a-z0-9_-]+\z/i)

      path = DIR.join("#{name}.yml")
      raise UnknownCollection, "Unknown collection: #{name}" unless path.file?

      Array(YAML.safe_load_file(path)).map { |e| e.transform_keys(&:to_s).merge("token_id" => e["token_id"].to_s) }
    end
  end
end
