require 'test_helper'
require 'minitest/spec'

class AuthOperationTest < Minitest::Spec
  include ActionMailer::TestHelper

  describe 'Auth::Operation::Create' do
    it "validates input, encrypts the password, saves user,
          creates a verify-account token and send a welcome email" do
      result = nil
      assert_emails 1 do
        result = Auth::Operation::CreateAccount.wtf?(
          {
            email: 'konj@gmail.com',
            password: '1234',
            password_confirm: '1234'
          }
        )
      end

      assert result.success?

      user = result[:user]
      assert user.persisted?
      assert_equal 'konj@gmail.com', user.email
      assert_equal 60, user.password.size
      assert_equal 'created, please verify account', user.state

      assert_match(/#{user.id}_.+/, result[:verify_account_token])

      verify_account_key = VerifyAccountKey.where(user_id: user.id)[0]

      assert_equal 43, verify_account_key.key.size

      assert_match(%r{/auth/verify_account/#{user.id}_#{verify_account_key.key}}, result[:email].body.to_s)
    end

    it 'fails on invalid input' do
      result = Auth::Operation::CreateAccount.wtf?(
        {
          email: 'konj@gmail',
          password: '1234',
          password_confirm: '1234'
        }
      )

      assert result.failure?
    end

    class NotRandom
      def self.urlsafe_base64(*)
        'this is not random'
      end
    end

    it 'fails when trying to insert the same {verify_account_token} twice' do
      options = {
        email: 'runjo@gmail.com',
        password: '1234',
        password_confirm: '1234',
        secure_random: NotRandom
      }

      result = Auth::Operation::CreateAccount.wtf?(options)
      assert result.success?
      assert_equal 'this is not random', result[:verify_account_key]

      result = Auth::Operation::CreateAccount.wtf?(options.merge(email: 'rofo@gmail.com'))
      assert result.failure?
      assert_equal 'Please try again.', result[:error]
    end
  end

  let(:valid_create_options) do
    {
      email: 'konj@gmail.com',
      password: '12345',
      password_confirm: '12345'
    }
  end

  describe 'VerifyAccount' do
    it 'allows finding an account from {verify_account_token}' do
      result = Auth::Operation::CreateAccount.wtf?(valid_create_options)
      assert result.success?

      verify_account_token = result[:verify_account_token]

      result = Auth::Operation::VerifyAccount.wtf?(verify_account_token:)
      assert result.success?

      user = result[:user]
      assert_equal 'ready to login', user.state
      assert_equal 'konj@gmail.com', user.email
      assert_nil VerifyAccountKey.where(user_id: user.id)[0]
    end

    it 'fails with invalid ID prefix' do
      result = Auth::Operation::VerifyAccount.wtf?(verify_account_token: '0_safasdfafsaf')
      assert result.failure?
    end

    it 'fails with invalid token' do
      result = Auth::Operation::CreateAccount.wtf?(valid_create_options)
      assert result.success?

      result = Auth::Operation::VerifyAccount.wtf?(verify_account_token: result[:verify_account_token] + 'rubbish')
      assert result.failure?

      result = Auth::Operation::VerifyAccount.wtf?(verify_account_token: '')
      assert result.failure?
    end

    it 'fails second time' do
      result = Auth::Operation::CreateAccount.wtf?(valid_create_options)
      assert result.success?

      result = Auth::Operation::VerifyAccount.wtf?(verify_account_token: result[:verify_account_token])
      assert result.success?
      result = Auth::Operation::VerifyAccount.wtf?(verify_account_token: result[:verify_account_token])
      assert result.failure?
    end
  end

  describe '#ResetPassword' do
    it 'fails with unknown email' do
      result = Auth::Operation::ResetPassword.wtf?(
        {
          email: 'i_do_not_exist@gmail.com'
        }
      )

      assert result.failure?
    end

    it 'resets password and sends a reset-password email' do
      result = Auth::Operation::CreateAccount.wtf?(valid_create_options)
      result = Auth::Operation::VerifyAccount.wtf?(verify_account_token: result[:verify_account_token])

      assert_emails 1 do
        result = Auth::Operation::ResetPassword.wtf?(
          {
            email: 'konj@gmail.com'
          }
        )

        assert result.success?

        user = result[:user]
        assert user.persisted?
        assert_equal 'konj@gmail.com', user.email
        assert_nil user.password
        assert_equal 'password reset, please change password', user.state

        assert_match(/#{user.id}_.+/, result[:reset_password_token])

        reset_password_key = ResetPasswordKey.where(user_id: user.id)[0]

        assert_equal 43, reset_password_key.key.size

        assert_match(%r{/auth/reset_password/#{user.id}_#{reset_password_key.key}}, result[:email].body.to_s)
      end
    end

    it 'fails when trying to insert the same {reset_password_token} twice' do
      result = Auth::Operation::CreateAccount.wtf?(valid_create_options)
      result = Auth::Operation::VerifyAccount.wtf?(verify_account_token: result[:verify_account_token])
      result = Auth::Operation::ResetPassword.wtf?(email: 'konj@gmail.com', secure_random: NotRandom)
      assert_equal 'this is not random', result[:key]

      result = Auth::Operation::CreateAccount.wtf?(valid_create_options.merge(email: 'sako@gmail.com'))
      result = Auth::Operation::VerifyAccount.wtf?(verify_account_token: result[:verify_account_token])
      result = Auth::Operation::ResetPassword.wtf?(email: 'sako@gmail.com', secure_random: NotRandom)
      assert result.failure?
      assert_equal 'Please try again.', result[:error]
    end
  end
  describe 'UpdatePassword::CheckToken' do
    it 'finds user by reset-password token and compares keys' do
      result = Auth::Operation::CreateAccount.call(valid_create_options)
      result = Auth::Operation::VerifyAccount.call(verify_account_token: result[:verify_account_token])
      result = Auth::Operation::ResetPassword.call(email: 'konj@gmail.com')
      token = result[:reset_password_token]

      result = Auth::Operation::UpdatePassword::CheckToken.wtf?(token:)
      assert result.success?

      original_key = result[:key]

      user = result[:user]
      assert user.persisted?
      assert_equal 'yogi@trb.to', user.email
      assert_nil user.password
      assert_equal 'password reset, please change password', user.state

      reset_password_key = ResetPasswordKey.where(user_id: user.id)[0]

      assert_equal original_key, reset_password_key
    end

    it 'fails with wrong token' do
      result = Auth::Operation::CreateAccount.call(valid_create_options)
      result = Auth::Operation::VerifyAccount.call(verify_account_token: result[:verify_account_token])
      result = Auth::Operation::ResetPassword.call(email: 'konj@gmail.com')
      token = result[:reset_password_token]

      result = Auth::Operation::UpdatePassword::CheckToken.wtf?(token: token + 'rubbish')
      assert result.failure?
    end
  end

  describe 'UpdatePassword' do
    it 'finds user by reset_password_token and updates password' do
      result = Auth::Operation::CreateAccount.call(valid_create_options)
      result = Auth::Operation::VerifyAccount.call(verify_account_token: result[:verify_account_token])
      result = Auth::Operation::ResetPassword.call(email: 'konj@gmail.com')
      token = result[:reset_password_token]

      result = Auth::Operation::UpdatePassword.wtf?(token:, password: '12345678', password_confirm: '12345678')
      assert result.success?

      user = result[:user]
      assert user.persisted?
      assert_equal 'konj@gmail.com', user.email
      assert_equal 60, user.password.size
      assert_equal 'ready to login', user.state

      assert_nil ResetPasswordKey.where(user_id: user.id)[0]
    end

    it 'fails with wrong password combo' do
      result = Auth::Operation::CreateAccount.call(valid_create_options)
      result = Auth::Operation::VerifyAccount.call(verify_account_token: result[:verify_account_token])
      result = Auth::Operation::ResetPassword.call(email: 'konj@gmail.com')
      token = result[:reset_password_token]

      result = Auth::Operation::UpdatePassword.wtf?(
        token:,
        password: '12345678',
        password_confirm: '123'
      )
      assert result.failure?
      assert_equal 'Passwords do not match.', result[:error]
      assert_nil result[:user].password
    end
  end
  describe 'Login' do
    it 'is successful with existing, active account' do
      result = Auth::Operation::CreateAccount.call(valid_create_options)
      result = Auth::Operation::VerifyAccount.call(verify_account_token: result[:verify_account_token])

      result = Auth::Operation::Login.wtf?(email: 'konj@gmail.com', password: '1234')
      assert result.success?

      result = Auth::Operation::Login.wtf?(email: 'konj@gmail.com', password: 'abcd')
      assert result.failure?
    end

    it 'fails with unknown email' do
      result = Auth::Operation::Login.wtf?(email: 'konj@gmail.com', password: 'abcd')
      assert result.failure?
    end
  end
end
