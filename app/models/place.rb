class Place
	include ActiveModel::Model
     
   	attr_accessor :id, :formatted_address, :location, :address_components

	# convenience method for access to client in console
	def self.mongo_client
		Mongoid::Clients.default
	end

	# convenience method for access to Racer collection
	def self.collection
		self.mongo_client['places']
	end

	# initialize from both a Mongo and Web hash
  	def initialize(params={})
    	Rails.logger.debug("instantiating Place (#{params})")

    	@id=params[:_id].to_s
 		@address_components||=[]
     	params[:address_components].to_a.each{ |ac| 
            @address_components.push(AddressComponent.new(ac))
        }
    	@formatted_address=params[:formatted_address]
    	@location=Point.new(params[:geometry][:geolocation])
  	end

	# bulk load a JSON document with places information into the places collection
	def self.load_all(file_path)
		Rails.logger.debug("load_all #{self} from file path (#{file_path})")

    	self.collection.delete_many({})
		file=File.read(file_path)
    	hash=JSON.parse(file)
    	self.collection.insert_many(hash)
	end

end
	