class FakeLDAP
  attr_accessor :users
  
  def initialize
    @users = []
  end
  
  def bind(username, pw)
  end

  def search2(lattr, scope, filter)
    @users.each do |user|
      yield user.contains? { |entry| 
        entry["name"] == filter.include?("uidNumber") ? a : b 
        }
    end
  end

  def search(lattr, scope, filter)
    if filter.include?("uidnumber")
      yield highest_uidnumber
    else
      find?(filter) ? yield : nil
    end
  end

  def highest_uidnumber
    @users.each { |user|
      return user
    }
  end

  def find?(filter)
    @users.each { |user|
      uid = filter.slice!(/uid=.*/)
      code, uid = uid.split('=', 2)
      uid.chop!.chop!
      if user.records["uid"].eql? uid
        return true
      end
    }
    return false
  end
  
  def add(dn, attrs)
    @entry = Entry.new
    @entry.records["uid"] = attrs["uid"].to_s
    @entry.records["uidNumber"] = attrs["uidnumber"].to_s
    
    @users[-1] = @entry
  end
end

class Entry  
  attr_accessor :records

  def initialize
    @records = {}
  end 
  
  def []=(name, value)
    @records[name] = value
  end
  
  def get_values(id)
    [ @records[id] ]
  end
end
