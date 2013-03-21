##############################################################################
#
# Ruby version 1.9
#
# Copyright 2012, Temboo Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
# either express or implied. See the License for the specific
# language governing permissions and limitations under the License.
#
#
# This application demonstrates how to get started building apps that
# integrate Last.fm and Google Calendar. To run the demo, you'll need
# a Temboo account, a Last.fm API Key, and oAuth 2.0 credentials for
# Google Calendar.
#
# The demo uses Temboo SDK functions to retrieve an XML list of Last.fm
# "events" associated with a list of your favorite bands, extracts the
# artist name, venue, city, and date for each event item, and adds an
# event to your Google Calendar if the event occurs in the city that you
# specify.
#
# @author Reid Simonton
#
##############################################################################

require 'rexml/document'

require 'temboo'
require 'Library/Google'
require 'Library/LastFM'

##############################################################################
# UPDATE THE VALUES OF THESE CONSTANTS WITH YOUR OWN CREDENTIALS
##############################################################################

if __FILE__ == $0
	# This constant defines your LastFM API Key
	LAST_FM_API_KEY = 'YOUR LAST.FM API KEY'
	
	# These constants define the oAuth credentials with which you access your GOOGLE account.
	GOOGLE_CLIENT_ID		= 'YOUR GOOGLE CLIENT ID'
	GOOGLE_CLIENT_SECRET	= 'YOUR GOOGLE CLIENT SECRET'
	GOOGLE_ACCESS_TOKEN		= 'YOUR GOOGLE ACCESS TOKEN'
	GOOGLE_REFRESH_TOKEN	= 'YOUR GOOGLE REFRESH TOKEN'
	
	# Use these constants to define the set of credentials that will be used 
	# to connect with Temboo.
	TEMBOO_ACCOUNT_NAME				= 'YOUR TEMBOO ACCOUNT NAME'
	TEMBOO_APPLICATION_KEY_NAME		= 'YOUR TEMBOO APPLICATION KEY NAME'
	TEMBOO_APPLICATION_KEY_VALUE	= 'YOUR TEMBOO APPLICATION KEY VALUE'
end

##############################################################################
# END CONSTANTS; NOTHING BELOW THIS POINT SHOULD NEED TO BE CHANGED
##############################################################################

class LastFMToGoogleCalendar
	
	# Constructor - initialize
	def initialize(session = nil)
		@events_added = 0
		@events_found = 0
		@session = (session == nil || !session.instance_of(TembooSession)) ? init_temboo() : session;
	end
	
	# Search for events for the given band
	# Question - (more of a comment) - seems like it would be a good idea to have exceptions
	# named the same across SDKs, e.g. Ruby vs. PHP vs. ...
	def find_events(calendar_name, my_town, band)
		begin
			# Get the calendar ID by name
			@calendar_name	= calendar_name
			@calendar_id	= get_calendar_id()
			
			# Find events for the given artist and town
			events = search_events(band, my_town)
			
			if(events.size > 0)
				puts "Found #{events.size} matching " + (events.size > 1 ? 'shows' : 'show') + ", adding to Google calendar"
				# Save events to user's calendar
				save_events(events)
				
				puts "Successfully added #{@events_added} of #{events.size} events to #{@calendar_name}"
			else
				puts "No '#{band}' events found in #{my_town}"
			end
		rescue TembooCredentialError => e
			puts "A Temboo authentication exception occured. Make sure your Temboo App Key name and value are correct."
		rescue TembooHTTPError => e
			puts "A Temboo error occurred while attempting to run a choreo. The error was: " + e.get_Message()
		rescue TembooObjectNotAccessibleError => e
			puts "A Temboo error occurred while attempting to access a required resource: " + e.get_Message()
		rescue TembooError => e
			puts "A general Temboo error occurred: " + e.get_Message()
		rescue
			puts "An unknown error occurred"
			raise
		end
	end
	
	# Save an event to Google Calendar
	# Question - must we create a new choreo each time through the loop, and re-set
	# redundant inputs such as GOOGLE_CLIENT_ID?  Or can we cache the choreo and reuse
	# it, setting only those inputs that have changed (e.g. EventTitle)?
	def save_event(event)
		
		# Instantiate the choreography, using the session object
		choreo = Google::Calendar::CreateEvent.new(@session)
		
		#Get an InputSet object for the choreo
		inputs = choreo.new_input_set()
		
		# Set inputs
		inputs.set_ClientID(GOOGLE_CLIENT_ID);
		inputs.set_ClientSecret(GOOGLE_CLIENT_SECRET);
		inputs.set_RefreshToken(GOOGLE_REFRESH_TOKEN);
		
		inputs.set_CalendarID(@calendar_id);
		
		inputs.set_EventTitle(event['title']);
		inputs.set_EventLocation(event['venue']);
		inputs.set_EventDescription(event['description']);
		
		# Note that start/end date/time are the same, as we don't know how
		# long the event will take
		inputs.set_StartDate(event['date']);
		inputs.set_StartTime(event['time']);
		inputs.set_EndDate(event['date']);
		inputs.set_EndTime(event['time']);
		
		begin
			# Execute choreography
			results = choreo.execute(inputs)
			
			puts "Successfully added #{event['venue']} date to #{@calendar_name}"
			@events_added += 1
		rescue
			puts 'Failed to save event to Calendar'
			raise
		end
	end
	
	# Format events data, save events to Google Calendar
	def save_events(events)
		events.each do |event|
			# Separate out and format the event's start date and time
			event_date = DateTime.parse(event['startDate'])
			
			event.delete('startDate')
			
			event['date']	= event_date.strftime('%Y-%m-%d');
			event['time']	= event_date.strftime('%T');
			
			save_event(event)
		end
	end
	
	def search_events(band, my_town, last_fm_api_key = LAST_FM_API_KEY)
		puts "Querying LastFM for '#{band}' shows in #{my_town}"
		
		# Instantiate the choreography, using the session object
		choreo = LastFm::Artist::GetEvents.new(@session)
		
		#Get an InputSet object for the choreo
		inputs = choreo.new_input_set()
		
		# Set inputs
		inputs.set_APIKey(last_fm_api_key);
		inputs.set_Artist(band);
		
		begin
			events = Array.new
			
			# Execute choreography
			results = choreo.execute(inputs)
			
			# Load/parse the XML
			events_xml = REXML::Document.new(results.get_Response())

			# How many events are there, across all venues?
			@events_found = Integer(events_xml.root.elements['events'].attributes['total'])
			#puts "Found #{@events_found} '#{band}' shows"
						
			if(@events_found > 0)
				# Pull out events in the specified town, if any
				events_xml.root.each_element('//event') do |event|
					
					event_description	= event.elements['description'].text
					event_town			= event.elements['venue/location/city'].text
					
					if(event_town != nil && 0 == my_town.casecmp(event_town))
						# Pull out the data we're interested in
						events.push({
							'city'			=> event_town,
							'startDate'		=> event.elements['startDate'].text,
							'title'			=> event.elements['title'].text,
							'venue'			=> event.elements['venue/name'].text,
						})
						
						# Add the description iff it's available
						if(event_description)
							events['description'] = event_description
						end
					end
				end
			end
			
			return events
		rescue
			puts "Failed to look up events for artist '#{band}'"
			raise
		end
	end
	
	# Look up a Google Calendar by name
	private
	def get_calendar_id
		# Instantiate the choreography, using the session object
		choreo = Google::Calendar::SearchCalendarsByName.new(@session)
		
		# Get an InputSet object for the choreo
		inputs = choreo.new_input_set()
		
		# Set inputs
		inputs.set_ClientSecret(GOOGLE_CLIENT_SECRET);
		inputs.set_AccessToken(GOOGLE_ACCESS_TOKEN);
		inputs.set_RefreshToken(GOOGLE_REFRESH_TOKEN);
		inputs.set_ClientID(GOOGLE_CLIENT_ID);
		
		inputs.set_CalendarName(@calendar_name);
		
		begin
			# Execute choreography
			results = choreo.execute(inputs)
			
			# Grab the calendar ID
			calendar_id = results.get_CalendarId()
			
			puts "Successfully located calendar '#{@calendar_name}'"
			
			return calendar_id
		rescue
			puts "Failed to locate calendar '#{@calendar_name}'"
			raise
		end
	end
	
	# Initialize Temboo session
	# QUESTION: ok to put function args on multiple lines like this?
	def init_temboo
		session = TembooSession.new(
			TEMBOO_ACCOUNT_NAME,
			TEMBOO_APPLICATION_KEY_NAME,
			TEMBOO_APPLICATION_KEY_VALUE
		)
		puts 'Successfully initialized Temboo session'
		return session
	end
	
end

if __FILE__ == $0
	instance = LastFMToGoogleCalendar.new
	instance.find_events('MyConcerts', ARGV[0], ARGV[1])
	puts 'Done'
end



