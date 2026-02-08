class Users::InvitationsController < Devise::InvitationsController

  def admin_destroy
    u = User.find(params[:id])

    respond_to do |format|
      if !u.invitation_accepted? && u.destroy
        format.html { redirect_to users_path, notice: "Die Einladung wurde gelöscht." }
      else
        format.html { redirect_to users_path, error: "Die Einladung konnte nicht gelöscht werden." }
      end
    end

  end

  private

    def after_invite_path_for(inviter, invitee)
      verwaltung_verleihende_path
    end

    def after_accept_path_for(resource)
      root_path # you can define this yourself. Just don't use session[:previous_url]
    end

    def invite_resource
      resource_class.invite!(invite_params, current_inviter) do |u|
        u.current_department = current_inviter.current_department

        logger.debug("\n \n params: #{invite_params["temp_role"].nil?} \n \n")

        if invite_params["temp_role"].nil? or invite_params["temp_role"].empty?
          u.current_role = 0 
        else
        
          if current_inviter.admin?
            u.current_role = invite_params["temp_role"]
          elsif current_inviter.leader?
            unless invite_params["temp_role"] == "leader" || invite_params["temp_role"] == "admin"
              u.current_role = invite_params["temp_role"]
            else
              u.current_role = 0
            end
          else
            u.current_role = 0
          end
        end
      end
    end
end