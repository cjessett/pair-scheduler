DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db.sqlite")

class Group
	include DataMapper::Resource

	property :id, Serial
	property :name, String

	has n, :users
	has n, :assignments
end

class User
	include DataMapper::Resource

	property :id, Serial, key: true
	property :name, String
	property :time_zone, String
	property :username, String, length: 128
	property :password, BCryptHash
	
	has n, :availabilities
	has n, :pairings, :child_key => [ :source_id ]
	has n, :matches, self, :through => :pairings, :via => :target

	belongs_to :group

	def authenticate(attempted_password)
    # The BCrypt class, which `self.password` is an instance of, has `==` defined to compare a
    # test plain text string to the encrypted string and converts `attempted_password` to a BCrypt
    # for the comparison.
    #
    # But don't take my word for it, check out the source: https://github.com/codahale/bcrypt-ruby/blob/master/lib/bcrypt/password.rb#L64-L67
    if self.password == attempted_password
      true
    else
      false
    end
  end
end

class Assignment
	include DataMapper::Resource

	property :id, Serial
	property :name, String
	property :number, Float

	has n, :availabilities
	has n, :pairings

	belongs_to :group
end

class Availability
	include DataMapper::Resource

	property :id, Serial
	property :date, Date
	property :start, DateTime
	property :end, DateTime

	belongs_to :user
	belongs_to :assignment

	def potential_matches
		matches = Hash.new
		potentials = Availability.all(:assignment_id => self.assignment_id, :date => self.date, :user_id.not => self.user_id)
		potentials.each do |potential|
			self.start >= potential.start ? latest_start = self.start : latest_start = potential.start
			self.end < potential.end ? earliest_end = self.end : earliest_end = potential.end
			if earliest_end.to_time - latest_start.to_time >= 3600
				matches[potential] = [latest_start, earliest_end]
			end
		end
	matches
	end
end

class Pairing
	include DataMapper::Resource

	property :date, Date
	property :start, DateTime
	property :end, DateTime

	belongs_to :assignment
	belongs_to :source, 'User', :key => true
	belongs_to :target, 'User', :key => true
end

DataMapper.finalize

DataMapper.auto_upgrade!


# Create a test User
if User.count == 0
	@group = Group.create(name: "admins")
	@group.save
	@user = User.create(username: "admin")
	@user.password = "admin"
	@user.group_id = 1
	@user.save
end









