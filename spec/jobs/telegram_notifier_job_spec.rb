require "rails_helper"

RSpec.describe TelegramNotifierJob, type: :job do
  let(:article) do
    create(:article,
           status:      "approved",
           title:       "Corruption! Probe ongoing.",
           description: "Officials said 10% of contracts were skimmed.",
           url:         "https://example.com/story?id=1")
  end

  let(:client)      { instance_double(TelegramClient) }
  let(:sent_texts)  { [] }

  before do
    allow(TelegramClient).to receive(:new).and_return(client)
    allow(client).to receive(:send_message) do |**kwargs|
      sent_texts << kwargs[:text]
      { "message_id" => 42 }
    end
  end

  it "escapes MarkdownV2 reserved characters in the URL" do
    described_class.perform_now(article.id)

    expect(sent_texts.last).to include("https://example\\.com/story?id\\=1")
  end

  it "leaves no unescaped MarkdownV2 reserved character except the bold markers" do
    described_class.perform_now(article.id)

    reserved = sent_texts.last.scan(/(?<!\\)[_*\[\]()~`>#+\-=|{}.!]/)
    expect(reserved).to eq(%w[* *]), "expected every MarkdownV2 reserved character to be escaped"
  end

  it "escapes the title and description" do
    described_class.perform_now(article.id)

    expect(sent_texts.last).to include("Corruption\\! Probe ongoing\\.")
    expect(sent_texts.last).to include("10% of contracts were skimmed\\.")
  end

  it "records the Telegram message id and notification time" do
    described_class.perform_now(article.id)

    article.reload
    expect(article.telegram_message_id).to eq(42)
    expect(article.notified_at).to be_present
  end

  context "when Telegram rejects the message" do
    before do
      allow(client).to receive(:send_message)
        .and_raise(TelegramClient::Error, "Telegram sendMessage failed: Bad Request (error_code=400)")
    end

    it "re-raises so Sidekiq retries the job" do
      expect { described_class.perform_now(article.id) }
        .to raise_error(TelegramClient::Error)
    end
  end
end
