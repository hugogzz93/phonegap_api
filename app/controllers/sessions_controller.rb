class SessionsController < ApplicationController
	def create
		user_password = params[:session][:password]
		user_email = params[:session][:email].downcase
		user = user_email.present? && User.find_by(email: user_email)

		if user
			if user.valid_password? user_password
				sign_in user, store: false
				user.generate_authentication_token!
				user.save
				render json: user, status: 200, location: [ user]
			else
				render json: { errors: 'Invalid email or password' }, status: 422
			end
		else
				render json: { errors: 'Invalid email or password' }, status: 422
		end
	end

	def destroy
		if user = User.find_by(auth_token: params[:id])
			user.generate_authentication_token!
			user.save
		end
		head 204
	end
end
