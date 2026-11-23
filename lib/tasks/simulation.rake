namespace :simulation do
  def simulation_wallet!(wallet)
    abort "Wallet must be 0x + 40 hex chars" unless wallet.to_s.match?(Simulation::WALLET_FORMAT)
    wallet.downcase
  end

  def simulation_guard!
    if Rails.env.production? && !Simulation.enabled?
      abort "Refusing to run in production without SIMULATION_MODE=true"
    end
  end

  desc "Assign random simulated NFTs: simulation:assign[wallet,count,collection]"
  task :assign, %i[wallet count collection] => :environment do |_t, args|
    simulation_guard!
    wallet     = simulation_wallet!(args[:wallet])
    count      = Integer(args[:count] || 0, exception: false)
    abort "count must be a positive integer" unless count&.positive?
    collection = args[:collection].presence || Simulation.collection

    begin
      result = Simulation::AssignCards.call(wallet: wallet, count: count, collection: collection)
    rescue Simulation::Catalog::UnknownCollection, ArgumentError => e
      abort e.message
    end
    puts "Assigned #{result.assigned.size}/#{result.requested} new cards to #{wallet} " \
         "(collection: #{collection}, total: #{result.total}): #{result.assigned.join(', ')}"
  end

  desc "List simulated NFTs of a wallet: simulation:list[wallet]"
  task :list, [:wallet] => :environment do |_t, args|
    simulation_guard!
    wallet = simulation_wallet!(args[:wallet])
    nfts = SimulatedNft.where(wallet_address: wallet).order(:collection, :id)
    puts "#{nfts.size} card(s) for #{wallet}"
    nfts.each { |n| puts "  #{n.collection}##{n.token_id}  #{n.name}  burn_power=#{n.burn_power}  #{n.status}" }
  end

  desc "Delete all simulated NFTs of a wallet: simulation:reset[wallet]"
  task :reset, [:wallet] => :environment do |_t, args|
    simulation_guard!
    wallet = simulation_wallet!(args[:wallet])
    puts "Deleted #{SimulatedNft.where(wallet_address: wallet).delete_all} card(s) for #{wallet}"
  end
end
