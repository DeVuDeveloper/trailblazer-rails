module Auth
  module Activity
    class CreateKey < Trailblazer::Operation
      step :generate_key
      step :save_key

      def generate_key(ctx, secure_random: SecureRandom, **)
        ctx[:key] = secure_random.urlsafe_base64(32)
      end

      def save_key(ctx, key:, user:, key_model_class:, **)
        key_model_class.create(user_id: user.id, key:)
      rescue ActiveRecord::RecordNotUnique
        ctx[:error] = 'Please try again.'
        false
      end
    end
  end
end
