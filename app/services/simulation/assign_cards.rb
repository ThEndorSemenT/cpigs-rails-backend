module Simulation
  # Assigns random catalog tokens to a wallet. Idempotent and bounded by the
  # catalog: a token already owned by the wallet is never picked again, and the
  # unique index guards against races. Reusable by the future bot player.
  class AssignCards
    Result = Struct.new(:assigned, :total, :requested, keyword_init: true)

    def self.call(**kwargs) = new(**kwargs).call

    def initialize(wallet:, count:, collection: Simulation.collection)
      @wallet     = wallet.to_s.downcase
      @count      = count.to_i
      @collection = collection.presence || Simulation.collection
    end

    def call
      raise ArgumentError, "Invalid wallet address" unless @wallet.match?(Simulation::WALLET_FORMAT)
      raise ArgumentError, "count must be positive" unless @count.positive?

      catalog = Catalog.entries(@collection)
      owned   = SimulatedNft.where(wallet_address: @wallet, collection: @collection).pluck(:token_id)
      picks   = catalog.reject { |e| owned.include?(e["token_id"]) }.sample(@count)

      rows = picks.map { |e| row_for(e) }
      inserted = rows.empty? ? [] : SimulatedNft.insert_all(
        rows, unique_by: :index_simulated_nfts_on_wallet_collection_token, returning: %w[token_id]
      ).rows.flatten

      Result.new(assigned: inserted, total: owned.size + inserted.size, requested: @count)
    end

    private

    def row_for(entry)
      now = Time.current
      {
        wallet_address: @wallet, collection: @collection, token_id: entry["token_id"],
        name: entry["name"], image_url: entry["image"], burn_power: entry["burn_power"].to_i,
        status: "available", metadata: {}, created_at: now, updated_at: now
      }
    end
  end
end
