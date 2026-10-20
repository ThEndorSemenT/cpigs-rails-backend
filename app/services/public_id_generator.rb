# frozen_string_literal: true

# Generates cryptographically secure candidate public IDs.
#
# This generator has no knowledge of models or persistence.
# It only returns candidate values that are safe for use in URLs.
class PublicIdGenerator
  PREFIX = 'EM'.freeze
  ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'.freeze.chars.freeze
  RANDOM_PART_LENGTH = 12

  class << self
    # Returns a new candidate public ID.
    # Example: EM7QF82KPXWN
    def generate
      PREFIX + RANDOM_PART_LENGTH.times.map { random_character }.join
    end

    private

    def random_character
      ALPHABET[SecureRandom.random_number(ALPHABET.length)]
    end
  end
end
