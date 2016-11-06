class Photo
	include ActiveModel::Model

    attr_accessor :id, :location, :contents

	# convenience method for access to client in console
	def self.mongo_client
		Mongoid::Clients.default
	end

	# tell Rails whether this instance is persisted
  def persisted?
    	!@id.nil?
  end

	# initialize from both a Mongo and Web hash
  def initialize(doc=nil)
		@id=doc[:_id].to_s if !doc.nil?
    @location=Point.new(doc[:metadata][:location]) if !doc.nil?
  end

 	# store a new instance into GridFS
  def save
    if !persisted?
      gps=EXIFR::JPEG.new(@contents).gps
      @location=Point.new(:lng=>gps.longitude,:lat=>gps.latitude)
      @contents.rewind

      description = {}
      description[:content_type]='image/jpeg'    
      description[:metadata]={:location=>@location.to_hash}  

      grid_file = Mongo::Grid::File.new(@contents.read,description)
      @id=Photo.mongo_client.database.fs.insert_one(grid_file).to_s
    end  
	end

  # return a collection of Photo instances representing each file 
  # returned from the database
  def self.all(skip=0,limit=nil)
    result=Photo.mongo_client.database.fs.find({})
      .skip(skip)
    result=result.limit(limit) if !limit.nil?
    result.map{|doc| Photo.new(doc) }
  end

  # return an instance of a Photo based on the input id
  def self.find(id)
    Rails.logger.debug {"find gridfs file #{@id}"}
    doc=Photo.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(id.to_s)).first
    if doc
      Photo.new(doc)
    end
  end

  # return the data bytes
  def contents
    if persisted?
      f=Photo.mongo_client.database.fs.find_one(:_id=>BSON::ObjectId.from_string(@id))
      if f 
        buffer = ""
        f.chunks.reduce([]) do |x,chunk| 
          buffer << chunk.data.data 
        end
        return buffer
      end 
    end
  end
  
  # delete the file and its contents from GridFS
  def destroy
    Rails.logger.debug {"destroying gridfs file #{@id}"}
    if persisted?
      Photo.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id)).delete_one
    end
  end
end
	