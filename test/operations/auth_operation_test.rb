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
            email: 'drvu@gmail.com',
            password: 'secure',
            password_confirm: 'secure'
          }
        )
      end

      assert result.success?

      user = result[:user]
      assert user.persisted?
      assert_equal 'drvu@gmail.com', user.email
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
          email: 'drvu@gmail',
          password_confirm: 'secure'
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
        email: 'me@gmail.com',
        password: 'secure',
        password_confirm: 'secure',
        secure_random: NotRandom
      }

      result = Auth::Operation::CreateAccount.wtf?(options)
      assert result.success?
      assert_equal 'this is not random', result[:verify_account_key]

      result = Auth::Operation::CreateAccount.wtf?(options.merge(email: 'me22@gmail.com'))
      assert result.failure?
      assert_equal 'Please try again.', result[:error]
    end
  end
end
