require 'minitest/spec'
require 'test_helper'

class AuthOperationTest < Minitest::Spec
  describe 'Auth::Operation::Create' do
    it 'accepts valid email and passwords' do
      result = Auth::Operation::CreateAccount.wtf?(
        {
          email: 'drvu@gmail.com',
          password: 'secret',
          password_confirm: 'secret'
        }
      )

      assert result.success?
    end
    it 'fails on invalid input' do
      result = Auth::Operation::CreateAccount.wtf?(
        {
          email: 'drvu@gmail',
          password: 'secret',
          password_confirm: 'secret'
        }
      )

      assert result.failure?
    end
  end
end
