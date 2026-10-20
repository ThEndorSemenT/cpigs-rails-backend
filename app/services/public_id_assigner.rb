# frozen_string_literal: true

# Assigns a globally unique public_id to a record.
#
# This service does not know anything about the host model beyond the
# presence of a `public_id` attribute. It relies on the database unique
# constraint to guarantee global uniqueness.
class PublicIdAssigner
  MAX_RETRIES = 5

  class PublicIdGenerationError < StandardError; end

  class << self
    # Ensure the record has a public_id candidate, but do not save it.
    def assign!(record)
      return record if record.public_id.present?

      record.public_id = PublicIdGenerator.generate
      record
    end

    # Save a record while retrying on public_id collisions.
    def assign_and_save!(record)
      assign!(record)
      with_unique_public_id_retry(record) do
        record.save!
      end
    end

    # Wrap a block and retry it when the public_id conflicts in the database.
    def with_unique_public_id_retry(record)
      attempts = 0

      begin
        yield
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
        raise unless public_id_conflict?(error)

        attempts += 1
        raise PublicIdGenerationError, "Could not generate unique public_id after #{MAX_RETRIES} attempts" if attempts >= MAX_RETRIES

        record.public_id = PublicIdGenerator.generate
        retry
      end
    end

    private

    def public_id_conflict?(error)
      message = error.message.to_s.downcase
      return true if message.include?('public_id')

      # Some adapters may wrap the original error in a StatementInvalid.
      cause_message = error.cause&.message.to_s&.downcase
      return true if cause_message&.include?('public_id')

      false
    end
  end
end
