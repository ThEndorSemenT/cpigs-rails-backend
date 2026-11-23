require "rails_helper"
require "rake"

RSpec.describe "simulation rake tasks" do
  let(:wallet) { "0x#{'cd' * 20}" }

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("simulation:assign")
  end

  def run(name, *args)
    Rake::Task[name].reenable
    Rake::Task[name].invoke(*args)
  end

  it "assigns cards, idempotently across two runs" do
    expect { run("simulation:assign", wallet, "10") }.to output(/Assigned 10\/10/).to_stdout
    expect { run("simulation:assign", wallet, "10") }.to output(/Assigned 10\/10/).to_stdout
    expect(SimulatedNft.where(wallet_address: wallet).count).to eq(20)
  end

  it "aborts on invalid wallet or count" do
    expect { run("simulation:assign", "0x123", "1") }.to raise_error(SystemExit).and output(/0x \+ 40 hex/).to_stderr
    expect { run("simulation:assign", wallet, "0") }.to raise_error(SystemExit).and output(/positive/).to_stderr
  end

  it "lists and resets" do
    run("simulation:assign", wallet, "3")
    expect { run("simulation:list", wallet) }.to output(/3 card\(s\)/).to_stdout
    expect { run("simulation:reset", wallet) }.to output(/Deleted 3/).to_stdout
    expect(SimulatedNft.count).to eq(0)
  end

  it "refuses in production when simulation is not allowed", :simulation_not_allowed do
    allow(Rails.env).to receive(:production?).and_return(true)
    expect { run("simulation:assign", wallet, "1") }.to raise_error(SystemExit).and output(/production/).to_stderr
    expect(SimulatedNft.count).to eq(0)
  end

  it "runs in production when simulation is allowed" do
    allow(Rails.env).to receive(:production?).and_return(true)
    expect { run("simulation:assign", wallet, "1") }.to output(/Assigned 1\/1/).to_stdout
  end
end
