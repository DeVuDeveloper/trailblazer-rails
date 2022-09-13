require 'minitest/spec'
require 'test_helper'

class AuthOperationTest < Minitest::Spec
  describe 'Auth::Operation::Create' do
    it 'accepts valid email and passwords' do
      result = Auth::Operation::CreateAccount.wtf?(
        {
          email: 'ar@gmail.com',
          password: 'secret',
          password_confirm: 'secret'
        }
      )

      assert result.success?
    end

    it 'fails on invalid input' do
      result = Auth::Operation::CreateAccount.wtf?(
        {
          email: 'ar@gmail',
          password: 'secret',
          password_confirm: 'secret'
        }
      )

      assert result.failure?
    end
    it 'validates input, encrypts the password, and saves user' do
      result = Auth::Operation::CreateAccount.wtf?()

      assert result.success?
      user = result[:user]
      assert user.persisted? 
      assert_equal 'yogi@trb.to', user.email
      assert_equal 60, user.password.size
      ass
    end
  end
end
