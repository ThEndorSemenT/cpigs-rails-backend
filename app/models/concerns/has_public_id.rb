# frozen_string_literal: true

# Concern to add a globally unique, immutable public identifier to a model.
#
# This concern is deliberately minimal:
# - it assigns a new Public ID before validation on create,
# - it uses database uniqueness as the source of truth,
# - it retries on unique key collisions during insert,
# - it blocks any attempt to change the public_id after assignment,
# - it exposes a class-level finder and URL-safe param behavior.
module HasPublicId
  extend ActiveSupport::Concern

  included do
    before_validation :assign_public_id, on: :create
    # Fallback for creates that skip validations (e.g. `save(validate: false)`),
    # where the before_validation callback above never runs.
    before_create :assign_public_id
    around_create :retry_create_with_public_id

    validates :public_id, presence: true
    validate :public_id_immutable, on: :update
  end

  class_methods do
    # Finds a record by the globally unique public_id and raises if not found.
    def find_by_public_id!(public_id)
      find_by!(public_id: public_id)
    end

    # Finds a record by either the internal id or the public_id.
    #
    # This keeps controller lookup logic compatible with legacy numeric ids
    # while allowing new URLs to use public_id values.
    # Works correctly when called on scoped relations (e.g., Model.with_deleted.find_by_param!(...)).
    def find_by_param!(identifier)
      return find(identifier) if identifier.to_s =~ /\A\d+\z/

      find_by!(public_id: identifier)
    end

    # Returns the record by internal id or public_id without raising.
    def find_by_param(identifier)
      return find_by(id: identifier) if identifier.to_s =~ /\A\d+\z/

      find_by(public_id: identifier)
    end
  end

  # Use the visible public identifier in Rails URL helpers.
  def to_param
    public_id.presence || id.to_s
  end

  def display_id
    public_id.presence || id
  end

  private

  def assign_public_id
    PublicIdAssigner.assign!(self)
  end

  def retry_create_with_public_id
    PublicIdAssigner.with_unique_public_id_retry(self) do
      yield
    end
  end

  def public_id_immutable
    return unless persisted? && public_id_was.present? && will_save_change_to_public_id?

    errors.add(:public_id, 'cannot be changed once assigned')
  end
end
