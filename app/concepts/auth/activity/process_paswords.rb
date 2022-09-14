module Auth::Activity
  class ProcessPasswords < Trailblazer::Operation
    step :identical?
    raise :not_identical, fail_fast: true
    step :valid?
    raise :not_valid, fail_fast: true
    step :password_hash

    def identical?(_ctx, password:, password_confirm:, **)
      password == password_confirm
    end

    def valid?(_ctx, password:, **)
      password && password.size >= 4
    end

    def not_identical(ctx, **)
      ctx[:error] = 'Passwords do not match.'
    end

    def not_valid(ctx, **)
      ctx[:error] = 'Password does not meet requirements.'
    end

    def password_hash(ctx, password:, bcrypt_cost: BCrypt::Engine::MIN_COST, **)
      ctx[:password_hash] = BCrypt::Password.create(password, cost: bcrypt_cost)
    end
  end
end
