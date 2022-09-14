module Auth::Operation
  class Login < Trailblazer::Operation
    step :find_user
    step :password_hash_match?

    def find_user(ctx, email:, **)
      ctx[:user] = User.find_by(email:)
    end

    def password_hash_match?(_ctx, user:, password:, **)
      BCrypt::Password.new(user.password) == password
    end
  end
end
