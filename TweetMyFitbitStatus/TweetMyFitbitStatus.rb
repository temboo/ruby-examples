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
# This simple Ruby application demonstrates how to get started building 
# cool Fitbit apps with the Temboo SDK. To run the demo, you'll need a 
# Temboo account, and oAuth credentials for both Twitter and Fitbit.
# 
# The demo uses Temboo SDK functions to retrieve the number of "steps"
# you've taken today from the Fitbit API, and based on whether or not 
# you've reached a predefined goal for the number of steps you aimed 
# to take, sends out a Tweet either proclaiming your success or admitting
# your shortfall.
#
# @author Katalina Mustatea
##############################################################################

require 'rexml/document'
require 'temboo'
require "Library/Fitbit"
require "Library/Twitter"

##############################################################################
# UPDATE THE VALUES OF THESE CONSTANTS WITH YOUR OWN CREDENTIALS
##############################################################################

# Okay, first things first -- set the messages that will be Tweeted based on 
# whether or not you met your goal. (Remember, Tweets are limited to 140 characters.)
GOAL_MET_MESSAGE = "Iron Man triathalon, here I come!"
GOAL_NOT_MET_MESSAGE = "Today I was a couch potato. Sigh."

# Specify your benchmark. This represents that amount of steps that you think you should hit.
# Fitbit defaults to a goal of 10,000, but you can adjust that here if you like.
BENCHMARK = 10000

# Use these constants to define the set of Fitbit oauth credentials that will be used 
# to access your Fitbit account. If you don't have these yet, go to https://dev.fitbit.com/ 
# and register your app. You will get the OauthConsumerKey and OauthConsumerSecret after 
# registering. Follow the instructions here to retrieve your Token and TokenSecret: 
# https://wiki.fitbit.com/display/API/OAuth+Authentication+in+the+Fitbit+API
# (Replace with your own Fitbit credentials.)

FITBIT_CONSUMER_KEY = "YOUR FITBIT OAUTH CONSUMER KEY"
FITBIT_CONSUMER_SECRET = "YOUR FITBIT OAUTH CONSUMER SECRET"
FITBIT_ACCESS_TOKEN = "YOUR FITBIT OAUTH TOKEN"
FITBIT_ACCSS_TOKEN_SECRET = "YOUR FITBIT OAUTH TOKEN SECRET"

# Use these constants to define the set of Twitter credentials that will be used to access 
# your Twitter account. If you don't have these yet, sign up for a dev account and register 
# your app here: https://dev.twitter.com/. You will be given the oauth creds that are needed.
# (Replace with your own Twitter oauth credentials.)
TWITTER_CONSUMER_KEY = "YOUR TWITTER OAUTH CONSUMER KEY"
TWITTER_CONSUMER_SECRET = "YOUR TWITTER OAUTH CONSUMER SECRET"
TWITTER_ACCESS_TOKEN = "YOUR TWITTER OAUTH TOKEN"
TWITTER_ACCESS_TOKEN_SECRET = "YOUR TWITTER OAUTH TOKEN SECRET"

# Use these constants to define the set of credentials that will be used 
# to connect with Temboo.
TEMBOO_ACCOUNT_NAME = "YOUR ACCOUNT NAME"
TEMBOO_APPLICATIONKEY_NAME = "YOUR APPKEY NAME"
TEMBOO_APPLICATIONKEY = "YOUR APPKEY"

##############################################################################
# END CONSTANTS; NOTHING BELOW THIS POINT SHOULD NEED TO BE CHANGED
##############################################################################


class TweetMyFitbitStatus
  
  # Create a new Temboo session, that will be used to run Temboo SDK choreos.
  def initialize()
      @session = TembooSession.new(TEMBOO_ACCOUNT_NAME,
                                        TEMBOO_APPLICATIONKEY_NAME,
                                        TEMBOO_APPLICATIONKEY)
  end
  
  # Get your total number of steps using the Fitbit::GetTimeSeriesByPeriod choreo.
  def get_steps()
    
    steps_total_choreo = Fitbit::GetTimeSeriesByPeriod.new(@session)
    
    # Inputs for the steps retrieval choreo.
    fitbit_inputs = steps_total_choreo.new_input_set()
    
    # Set input values. This choreo takes inputs specifying some time period params, 
    # a Fitbit resource path, and your Fitbit oauth credentials. 
    fitbit_inputs.set_EndDate("today")          
    fitbit_inputs.set_ConsumerKey(FITBIT_CONSUMER_KEY)
    fitbit_inputs.set_ConsumerSecret(FITBIT_CONSUMER_SECRET)
    fitbit_inputs.set_AccessToken(FITBIT_ACCESS_TOKEN)
    fitbit_inputs.set_AccessTokenSecret(FITBIT_ACCSS_TOKEN_SECRET)          
    fitbit_inputs.set_Period("1d")
    fitbit_inputs.set_ResourcePath("activities/steps")
    
    # Run the GetTimeSeriesByPeriod choreo, to retrieve the amount of steps that 
    # you've taken today from FitBit.
    fitbit_result = steps_total_choreo.execute(fitbit_inputs)
    
    # Print out some status info to make sure this thing is working.
    puts "Retrieved XML from Fitbit"
    
    #Convert the Fitbit data to XML.
    fitbit_logs = REXML::Document.new(fitbit_result.get_Response())
    
    # Extract the <value> element that contains the number of steps you walked.
    steps_walked = fitbit_logs.root.elements['////value'].text
    
    # Print out the number of steps you walked today according to Fitbit.
    puts "Fitbit says that you have walked #{steps_walked} steps!"
    
    # Based on the amount of steps we retrieved from Fitbit, we'll tweet your shameful 
    # or braggy message.Have you walked enough steps?
    if steps_walked.to_i < BENCHMARK
      
      # Do some logging to make sure this thing is working. Plus a chance to shame you 
      # for sitting around all day.
      puts "For shame!"
      
      # Create tweet containing your specified shameful message, since the number of 
      # steps retrieved from Fitbit < the benchmark specified.
      tweet_message(GOAL_NOT_MET_MESSAGE)
      
    elsif  steps_walked.to_i >= BENCHMARK
      
      # Do some logging to make sure this thing is working. Plus a chance to 
      # congratulate you on your active day.
      puts "Wow, you're good!"
      
      # Create tweet containing your specified braggy message, since the number of 
      # steps retrieved from Fitbit is more than the benchmark.
      tweet_message(GOAL_MET_MESSAGE)
      
    end

  end
  
  # This function will run the choreo that updates your Twitter feed.
  def tweet_message(message)
    
    # Create a Twitter::Tweets::StatusesUpdate choreo, that will be used to update 
    #your Twitter feed, using the session object (as always)
    update_choreo = Twitter::Tweets::StatusesUpdate.new(@session)
    
    # Inputs for the steps retrieval choreo.
    update_inputs = update_choreo.new_input_set()
    
    # Set input values. This choreo takes inputs specifying Twitter oauth credentials
    # and the message appropriate to whether you have met your Fitbit goal today.
    update_inputs.set_ConsumerKey(TWITTER_CONSUMER_KEY)
    update_inputs.set_ConsumerSecret(TWITTER_CONSUMER_SECRET)
    update_inputs.set_AccessToken(TWITTER_ACCESS_TOKEN)
    update_inputs.set_AccessTokenSecret(TWITTER_ACCESS_TOKEN_SECRET)         
    update_inputs.set_StatusUpdate(message)
    
    # Now execute the StatusesUpdate choreo. If you encounter any problems,
    # Print out an error message.
    begin
      update_choreo.execute(update_inputs)
      puts "Successfully tweeted: #{message}"
      
    rescue Exception => e
      puts "Uh-oh! Something went wrong trying to update your Twitter status." 
      puts "The error from the choreo was: "
      puts e.message
      raise e
    end
  end
  
  def main()
    get_steps()
  end
end

instance = TweetMyFitbitStatus.new()
instance.main()


  
  
  
  