class AddressComponent
	include ActiveModel::Model
    
	attr_accessor :long_name, :short_name, :types

  	# initialize from both a Mongo and Web hash
  	def initialize(params={})
    	Rails.logger.debug("instantiating AddressComponent (#{params})")

    	@long_name=params[:long_name]
    	@short_name=params[:short_name]
    	@types=params[:types]
  	end
end
	