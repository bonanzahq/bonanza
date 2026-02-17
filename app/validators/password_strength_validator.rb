# ABOUTME: Validates password strength using entropy scoring and breach checking.
# ABOUTME: Combines zxcvbn scoring with unpwn breach detection.

class PasswordStrengthValidator < ActiveModel::EachValidator
  MINIMUM_SCORE = 3
  MAX_LENGTH_FOR_SCORING = 100

  def validate_each(record, attribute, value)
    return if value.blank?

    check_breach(record, attribute, value)
    check_strength(record, attribute, value, user_inputs(record))
  end

  private

  def check_breach(record, attribute, value)
    return unless Unpwn.new.pwned?(value)
    record.errors.add(attribute, :breached)
  rescue StandardError
    # Network failure - don't block the user
  end

  def check_strength(record, attribute, value, inputs)
    result = Zxcvbn.test(value[0...MAX_LENGTH_FOR_SCORING], inputs)
    return if result.score >= MINIMUM_SCORE

    record.errors.add(attribute, :too_weak)
  end

  def user_inputs(record)
    inputs = ["bonanza"]
    if record.respond_to?(:email) && record.email.present?
      inputs << record.email
      inputs << record.email.split("@").first
    end
    inputs << record.firstname if record.respond_to?(:firstname) && record.firstname.present?
    inputs << record.lastname if record.respond_to?(:lastname) && record.lastname.present?
    inputs
  end
end
