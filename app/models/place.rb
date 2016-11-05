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

	def self.to_places(params)
		places=[]
		params.each do |p|
			places.push(Place.new(p))
		end
		return places
	end

	# initialize from both a Mongo and Web hash
  	def initialize(params={})
    	Rails.logger.debug("instantiating Place (#{params})")

    	@id=params[:_id].to_s
 		@address_components||=[]
     	params[:address_components].to_a.each do |ac| 
            @address_components.push(AddressComponent.new(ac))
        end
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

	# return a Mongo::Collection::View with a query to match documents 
	# with a matching short_name within address_components
	def self.find_by_short_name(short_name)
		Rails.logger.debug {"getting palces matching #{short_name}"}

		result=collection.find({'address_components.short_name': short_name})
	end

	# return an instance of Place for a supplied id
	def self.find(id)
		Rails.logger.debug {"getting palce #{id}"}

		result = collection.find({'_id': BSON::ObjectId.from_string(id)}).first
		return result.nil? ? nil : Place.new(result)
	end

	# return an instance of all documents as Place instances
	# accept two optional arguments: offset and limit in that order
	def self.all(offset=0,limit=nil)
		Rails.logger.debug {'getting all palces, offset=#{offset}, limit=#{limit}'}

		result=collection.find({})
			.skip(offset)
		result=result.limit(limit) if !limit.nil?
		return self.to_places(result)
	end

	# delete the document associtiated with its assigned id
	def destroy
		Rails.logger.debug {"destroying #{self}"}

    	self.class.collection
              .find(:_id => BSON::ObjectId.from_string(@id))
              .delete_one   
	end

	# returns a collection of hash documents with address_components 
	# and their associated _id, formatted_address and location properties.
	def self.get_address_components(sort=nil,offset=0,limit=nil)
		Rails.logger.debug {'getting all address components, sort=#{sort}, offset=#{offset}, limit=#{limit}'}

		pipeline=[]
		pipeline.push({:$unwind=>"$address_components"})
		pipeline.push({:$project=>{_id:1,:address_components=>1,:formatted_address=>1,:geometry=>{:geolocation=>1}}})
		if(sort)
			pipeline.push({:$sort=>sort})
		end
		pipeline.push({:$skip=>offset})
		if(limit)
			pipeline.push({:$limit=>limit})
		end
		result=collection.find.aggregate(pipeline) 
	end

	# returns a distinct collection of country names (long_names)
	def self.get_country_names
		pipeline=[]
		pipeline.push({:$unwind=>"$address_components"})
		pipeline.push({:$project=>{_id:0,:address_components=>{:long_name=>1,:types=>1}}})
		pipeline.push({:$unwind=>"$address_components.types"})
		pipeline.push({:$match=>{'address_components.types'=>'country'}})
		pipeline.push({:$group=>{:_id=>"$address_components.long_name"}})
	 
		result=collection.find.aggregate(pipeline).to_a.map {|h| h[:_id]}
	end

	# return the id of each document in the places collection 
	# that has an address_component.short_name of type country and matches the provided parameter
	def self.find_ids_by_country_code(country_code)
		pipeline=[]
		pipeline.push({:$match=>{'address_components.types'=>'country', 'address_components.short_name'=>country_code}})
		pipeline.push({:$project=>{_id:1}})
		result=collection.find.aggregate(pipeline).map {|doc| doc[:_id].to_s}
	end
end
	