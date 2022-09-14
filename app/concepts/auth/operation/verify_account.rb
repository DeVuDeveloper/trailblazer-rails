module Auth::Operation
  class VerifyAccount < Trailblazer::Operation
    class CheckToken < Auth::Activity::CheckToken
      private def key_model_class
        VerifyAccountKey
      end
    end

    step Subprocess(CheckToken), input: { verify_account_token: :token }
    step :state
    step :save
    step :expire_verify_account_key

    def state(_ctx, user:, **)
      user.state = 'ready to login'
    end

    def save(_ctx, user:, **)
      user.save
    end

    def expire_verify_account_key(_ctx, key:, **)
      key.delete
    end
  end
end
