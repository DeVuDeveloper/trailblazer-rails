require 'minitest/spec'
require 'test_helper'

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
            password: '12345',
            password_confirm: '12345'
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
          password: '12345',
          password_confirm: '12345'
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
        email: 'konj@gmail.com',
        password: '12345',
        password_confirm: '12345',
        secure_random: NotRandom
      }

      result = Auth::Operation::CreateAccount.wtf?(options)
      assert result.success?
      assert_equal 'this is not random', result[:verify_account_key]

      result = Auth::Operation::CreateAccount.wtf?(options.merge(email: 'magare@gmail.com'))
      assert result.failure?
      assert_equal 'Please try again.', result[:error]
    end
  end

  describe 'VerifyAccount' do
    let(:valid_create_options) do
      {
        email: 'konj@gmail.com',
        password: '12345',
        password_confirm: '12345'
      }
    end

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
          email: 'i_do_not_exist@gmail@com'
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
  end
end
