module Auth::Operation
  class ResetPassword < Trailblazer::Operation
    step :find_user
    pass :reset_password
    step :state
    step :save_user
    step Subprocess(Auth::Activity::CreateKey),
         input: lambda { |ctx, user:, **|
                  { key_model_class: ResetPasswordKey, user: }.merge(ctx.to_h.slice(:secure_random))
                }
    step :send_reset_password_email

    def find_user(ctx, email:, **)
      ctx[:user] = User.find_by(email:)
    end

    def reset_password(_ctx, user:, **)
      user.password = nil
    end

    def state(_ctx, user:, **)
      user.state = 'password reset, please change password'
    end

    def save_user(_ctx, user:, **)
      user.save
    end

    def send_reset_password_email(ctx, key:, user:, **)
      token = "#{user.id}_#{key}"

      ctx[:reset_password_token] = token

      ctx[:email] = AuthMailer.with(email: user.email, reset_password_token: token).reset_password_email.deliver_now
    end
  end
end
