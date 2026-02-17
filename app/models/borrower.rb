class Borrower < ApplicationRecord
  has_many :lendings
  has_many :line_items, :through => :lendings
  has_many :conducts, :dependent => :destroy

	validates :firstname, :lastname, :email, :phone, presence: true
  validates :insurance_checked, inclusion: { in: [true], message: "Haftpflichtversicherung muss überprüft werden!" }, on: [:create, :update]
  validates :id_checked, inclusion: { in: [true], message: "Studierenden-/Mitarbeitendenausweis muss überprüft werden!" }, on: [:create, :update], if: Proc.new{|u| u.student? }
  #validates :email, :email => {:ban_disposable_email => true, :mx_with_fallback => true, :message => "ist ungültig."}, if: Proc.new{ Rails.env.production? } 
  validates :student_id, presence: true, if: Proc.new{|u| u.student? }
  validates :student_id, uniqueness: true, if: Proc.new{|u| u.student? && u.student_id.present? }
  validates :email, uniqueness: true
  validates :tos_accepted, inclusion: { in: [true], message: "Die Registrierung muss erst bestätigt werden"}, on: [:self]

  before_save :borrower_accepted_tos

  enum :borrower_type, { student: 0, employee: 1, deleted: 2 }

  searchkick word_middle: [:fullname, :email]

  def search_data
    {
      fullname: fullname,
      email: email,
      student_id: student_id,
      lendings: line_items.where(returned_at: nil).any? ? 'active' : 'none',
      conducts: conducts.any? ? conducts.collect(&:kind) : ['blameless'],
      borrower_type: borrower_type
    }
  end

  def fullname
    firstname + " " + lastname
  end

  def send_confirmation_pending_email
    create_token
    begin
      BorrowerMailer.with(borrower: self).confirm_email.deliver_now
    rescue Exception => e
      self.errors.add(:base, "Die E-Mail zur Bestätigung der Registrierung konnte leider nicht verschickt werden. Versuche es in einigen Minuten nochmal.")
      raise ActiveRecord::Rollback # so that the save will be rolled back
    end
  end

  def self.search_people( query, lending_status = nil, conducts = nil, borrower_type = nil, page )
    logger.debug("Searching for people \r")
    page = 1 unless page
    
    query = "*" if query.blank?
    
    where = {type: {not: "deleted"}}
    
    if lending_status.blank?
      where.merge!({lendings: ["active","none"] })
    end

    if lending_status.present? && lending_status.kind_of?(Array)
      l = lending_status.select{ |l| ["active", "none"].include?(l)} 
      where.merge!({lendings: l }) unless l.nil? && l.count < 1
    end

    if conducts.blank?
      where.merge!({conducts: ["blameless", "warned", "banned"] })
    end

    if conducts.present? && conducts.kind_of?(Array)
      c = conducts.select{ |c| ["blameless", "warned", "banned"].include?(c)} 
      where.merge!({conducts: c }) unless c.nil? && c.count < 1
    end

    if borrower_type.blank?
      where.merge!({borrower_type: ["student", "employee"] })
    end

    if borrower_type.present? && borrower_type.kind_of?(Array)
      b = borrower_type.select{ |b| ["student", "employee"].include?(b)} 
      where.merge!({borrower_type: b }) unless b.nil? && b.count < 1
    end
    
    begin
      results = self.search(query, where: where, load: true, page: page, per_page: 4, order: [{_score: :desc}, {fullname: :asc}], misspellings: {edit_distance: 2}, fields: [{"fullname^20" => :word_middle}, {"email^14" => :word_middle}, {"student_id" => :exact}])
      results.to_a # force lazy evaluation inside rescue
      results
    rescue Faraday::ConnectionFailed, Errno::ECONNREFUSED, Elastic::Transport::Transport::Error => e
      Rails.logger.warn("Elasticsearch unavailable: #{e.message}")
      Borrower.none.page(1).per(4)
    end
  end

  def has_misconduct_here?
    has_misconduct_in?(User.current_user.current_department)
  end

  def has_bans_here?
    has_bans_in?(User.current_user.current_department)
  end

  def has_misconduct_in?(dpt)
    conducts.where(department: dpt).any?
  end

  def has_bans_in?(dpt)
    conducts.where(department: dpt, kind: 'banned').any?
  end

  def has_warnings_in?(dpt)
    conducts.where(department: dpt, kind: 'warned').any?
  end

  private

    def borrower_accepted_tos
      return unless tos_accepted?
      self.tos_accepted_at = Time.now()
    end

    def create_token
      self.email_token ||= loop do
        random_token = SecureRandom.urlsafe_base64(64, false)
        break random_token unless self.class.exists?(email_token: random_token)
      end
      save(context: :token_creation)
    end

end
