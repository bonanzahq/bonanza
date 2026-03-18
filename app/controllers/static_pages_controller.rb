class StaticPagesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :ausleihbedingungen, :datenschutz, :impressum]

  def index
  end

  def lender
  end

  def ausleihbedingungen
  end

  def datenschutz
  end

  def impressum
  end

  def edit_single_legal_text
    authorize! :edit, LegalText

    @text = LegalText.find(params[:id])
    @tos_versions = LegalText.where(kind: 'tos').order(created_at: :desc, id: :desc)
  end

  def edit
    authorize! :edit, LegalText

    ensure_legal_texts_exist

    @tos_versions = LegalText.where(kind: 'tos').order(created_at: :desc, id: :desc)

    @current_tos = LegalText.current_tos
    @current_privacy = LegalText.current_privacy
    @current_imprint = LegalText.current_imprint
  end

  def update
    authorize! :edit, LegalText

    @legalText = LegalText.find(params[:id])

    @tos_versions = LegalText.where(kind: 'tos').order(created_at: :desc, id: :desc)

    @current_tos = LegalText.current_tos
    @current_privacy = LegalText.current_privacy
    @current_imprint = LegalText.current_imprint

    respond_to do |format|
      if @legalText.update_texts(legaltext_params)

        if @legalText.tos? && @legalText != LegalText.current_tos
          @legalText = LegalText.current_tos
        end

        format.turbo_stream {
          flash.now[:notice] = "Die Ausleihbedingungen wurden aktualisiert." if @legalText.tos?
          flash.now[:notice] = "Die Ausleihbedingungen wurden aktualisiert und die Ausleihenden wurden zur Zustimmung aufgefordert." if @legalText.notify_borrowers
          flash.now[:notice] = "Die Datenschutz wurde aktualisiert." if @legalText.privacy?
          flash.now[:notice] = "Das Impressum wurde aktualisiert." if @legalText.imprint?
        }
        format.html { redirect_to verwaltung_texte_path, notice: "Legaltext was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end

  end

  private

    # Only allow a list of trusted parameters through.
    def legaltext_params
      params.require(:legal_text).permit(:content, :notify_borrowers)
    end

    # Creates missing LegalText records with placeholder content.
    def ensure_legal_texts_exist
      defaults = {
        tos: "Ausleihbedingungen",
        privacy: "Datenschutzbestimmungen",
        imprint: "Impressum"
      }

      defaults.each do |kind, content|
        next if LegalText.where(kind: kind).exists?

        LegalText.create!(kind: kind, content: content, user: current_user)
      end
    end

end
