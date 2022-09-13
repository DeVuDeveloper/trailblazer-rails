module Auth::Operation
  class CreateAccount < Trailblazer::Operation
    step :check_email
    raise :email_invalid_msg, fail_fast: true
    step :passwords_identical?
    raise :passwords_invalid_msg, fail_fast: true
    step :password_hash
    step :state
    step :save_account

    def check_email(_ctx, email:, **)
      email =~ /\A[^,;@ \r\n]+@[^,@; \r\n]+\.[^,@; \r\n]+\z/
    end

    def passwords_identical?(_ctx, password:, password_confirm:, **)
      password == password_confirm
    end

    def email_invalid_msg(ctx, **)
      ctx[:error] = 'Email invalid.'
    end

    def passwords_invalid_msg(ctx, **)
      ctx[:error] = 'Passwords do not match.'
    end

    def password_hash(ctx, password:, password_hash_cost: BCrypt::Engine::MIN_COST, **)
      ctx[:password_hash] = BCrypt::Password.create(password, cost: password_hash_cost)
    end

    def state(ctx, **)
      ctx[:state] = 'created, please verify account'
    end

    def save_account(ctx, email:, password_hash:, state:, **)
      user = User.create(email:, password: password_hash, state:)
      ctx[:user] = user
    end
  end
end
