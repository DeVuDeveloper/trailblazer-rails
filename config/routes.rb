Rails.application.routes.draw do
  get "/auth/verify_account/:token" => "auth#verify_account", as: :verify_account
  get "/auth/reset_password/:token" => "auth#reset_password", as: :reset_password
end
