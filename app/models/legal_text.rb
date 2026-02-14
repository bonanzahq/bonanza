class LegalText < ApplicationRecord
	belongs_to :user
	enum :kind, { tos: 0, privacy: 1, imprint: 2 }

	def self.current_tos
		where(kind: "tos").last
	end

	def self.current_privacy
		where(kind: "privacy").last
	end

	def self.current_imprint
		where(kind: "imprint").last
	end

	def notify_borrowers
		@notify_borrowers || false
	end

	def update_texts(legaltext_params)

		if kind == "tos"
			if legaltext_params[:notify_borrowers].to_i == 1
				@notify_borrowers = true

				new_text = dup
				new_text.content = legaltext_params[:content]
				new_text.user = User.current_user

				new_text.save
			elsif id != LegalText.current_tos.id
				new_text = LegalText.current_tos.dup
				new_text.created_at = LegalText.current_tos.created_at
				new_text.content = content

				new_text.user = User.current_user

				new_text.save
			else
				legaltext_params.delete(:notify_borrowers)
				user = User.current_user
				update(legaltext_params)
			end
		else
			legaltext_params.delete(:notify_borrowers)
			user = User.current_user
			update(legaltext_params)
		end
	end

end
