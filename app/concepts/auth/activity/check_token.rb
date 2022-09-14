module Auth::Activity
  class CheckToken < Trailblazer::Operation
    step :extract_from_token
    step :find_key
    step :find_user
    step :compare_keys

    def extract_from_token(ctx, token:, **)
      id, key = Auth::TokenUtils.split_token(token)

      ctx[:id] = id
      ctx[:input_key] = key
    end

    def find_key(ctx, id:, **)
      ctx[:key] = key_model_class.where(user_id: id)[0]
    end

    def find_user(ctx, id:, **)
      ctx[:user] = User.find_by(id:)
    end

    def compare_keys(_ctx, input_key:, key:, **)
      Auth::TokenUtils.timing_safe_eql?(input_key, key.key)
    end

    private def key_model_class
      raise 'implement me'
    end
  end
end
