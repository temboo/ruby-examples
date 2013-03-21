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
# This is a simple Ruby application that demonstrates how to use the
# Temboo SDK to backup a set of Google Documents files to Dropbox.
# To run the demo, you'll need a Temboo account, and of course Dropbox
# and Google Docs accounts. The demo uses Temboo SDK functions to
# create a new folder to hold your backups of Dropbox, then retrieves a
# list of Google Documents files for the specified account, downloads
# each file and then uploads it to the Dropbox folder.
#
##############################################################################

require 'rexml/document'

require "Library/Dropbox"
require "Library/Google"

##############################################################################
# UPDATE THE VALUES OF THESE CONSTANTS WITH YOUR OWN CREDENTIALS
##############################################################################

# These constants define the oAuth credentials with which you access your
# Dropbox account.
DROPBOX_APP_KEY = "YOUR KEY"
DROPBOX_APP_SECRET = "YOUR SECRET"
DROPBOX_ACCESS_TOKEN = "YOUR TOKEN"
DROPBOX_ACCESS_TOKEN_SECRET = "YOUR TOKEN SECRET"

# Use this constant to define the name of the folder that will be created
# on Dropbox, and that will hold the set of uploaded documents. Note that
# another folder with the same name can't already exist on Dropbox.
DROPBOX_BACKUP_FOLDERNAME = "GoogleDocBackups"

# Use these constants to define the set of credentials that will be used 
# to access Google Documents.
GOOGLEDOCS_USERNAME = "YOUR USERNAME"
GOOGLEDOCS_PASSWORD = "YOUR PASSWORD"

# Use these constants to define the set of credentials that will be used 
# to connect with Temboo.
TEMBOO_ACCOUNT_NAME = "YOUR ACCOUNT NAME"
TEMBOO_APPLICATIONKEY_NAME = "YOUR APPKEY NAME"
TEMBOO_APPLICATIONKEY = "YOUR APPKEY"

##############################################################################
# END CONSTANTS; NOTHING BELOW THIS POINT SHOULD NEED TO BE CHANGED
##############################################################################


class GoogleDocumentsBackup

  # Set up Temboo session. Create a target folder in Dropbox.
  def initialize()
    @test_session = TembooSession.new(TEMBOO_ACCOUNT_NAME,
                                      TEMBOO_APPLICATIONKEY_NAME,
                                      TEMBOO_APPLICATIONKEY)
  end

  # Add a folder in your dropbox account in to which you will place your
  # backed up Google documents.
  def create_new_folder()
    # Use the Dropbox::CreateFolder choreo to  create a new folder.
    create_folder = Dropbox::CreateFolder.new(@test_session)
    # Inputs for the folder-creation choreo.
    inputs = create_folder.new_input_set()
        
    # Set input values. The Dropbox::CreateFolder choreo requires the name of
    # the folder to create, and the Dropbox credentials, as inputs
    inputs.set_NewFolderName(DROPBOX_BACKUP_FOLDERNAME)
    inputs.set_AccessToken(DROPBOX_ACCESS_TOKEN)
    inputs.set_AccessTokenSecret(DROPBOX_ACCESS_TOKEN_SECRET)
    inputs.set_AppKey(DROPBOX_APP_KEY)
    inputs.set_AppSecret(DROPBOX_APP_SECRET)

    # Create the folder by running the choreo.
    folder_result = create_folder.execute(inputs)
  end

  # Get the list of files to be backed up from Google Docs.
  def get_file_list()
    file_hash = {}

    # Choreo to retrieve document list.
    get_doc_list = Google::Documents::GetAllDocuments.new(@test_session)
    # Inputs for the list-fetching choreo.
    inputs = get_doc_list.new_input_set()
    # Configure inputs
    inputs.set_Username(GOOGLEDOCS_USERNAME)
    inputs.set_Password(GOOGLEDOCS_PASSWORD)
    inputs.set_Deleted("false")

    # Get Temboo result object.
    results = get_doc_list.execute(inputs)
    # Convert the XML response to REXML document object.
    result_tree = REXML::Document.new(results.get_Response())
    # Get the information that we will need to download the document.
    result_tree.root.each_element('//entry') {|entry|
      title = entry.elements['title'].text
      content = entry.elements['content']
      src = content.attributes['src']
      file_hash[title] = src
    }

    return file_hash
  end

  def download_from_google_docs(location)
    # If it's a spreadsheet, download the document with the
    # DownloadBase64EncodedSpreadsheet choreo.
    if location.include? "spreadsheet"
      choreo = Google::Spreadsheets::DownloadBase64EncodedSpreadsheet.new(@test_session)
      inputs = choreo.new_input_set()
    # Otherwise use DownloadBase64EncodedDocument.
    else
      choreo = Google::Documents::DownloadBase64EncodedDocument.new(@test_session)
      inputs = choreo.new_input_set()
      # Make sure we're expecting the right type of document.
      if location.include? "securesc"
        inputs.set_Format("pdf")
      else
        inputs.set_Format("doc")
      end
    end

    # The other properties are the same for both sheets and docs.
    inputs.set_Link(location)
    inputs.set_Username(GOOGLEDOCS_USERNAME)
    inputs.set_Password(GOOGLEDOCS_PASSWORD)
    inputs.set_Title("")

    # Run the choreo and return its results.
    results = choreo.execute(inputs)
    return results.get_FileContents()
  end

  def upload_to_dropbox(name, contents)
    choreo = Dropbox::UploadFile.new(@test_session)

    # Create input and set salient values.
    inputs = choreo.new_input_set()
    inputs.set_Folder(DROPBOX_BACKUP_FOLDERNAME)
    inputs.set_AccessToken(DROPBOX_OAUTH_TOKEN)
    inputs.set_AccessTokenSecret(DROPBOX_OAUTH_TOKEN_SECRET)
    inputs.set_AppKey(DROPBOX_OAUTH_CONSUMER_KEY)
    inputs.set_AppSecret(DROPBOX_OAUTH_CONSUMER_SECRET)
    inputs.set_FileContents(contents)
    inputs.set_FileName(name)

    # Upload the file to Dropbox.
    begin
        choreo.execute(inputs)
        puts "Uploaded #{name}"
    rescue Exception => e
        puts "An error occurred attempting to upload #{name}"
        raise e
    end
  end

  # Wraps things all up. Get the list of documents and upload each to
  # Dropbox.
  def main()
    create_new_folder()
    file_list = get_file_list()
    
    file_list.each_key { |file_name|
      contents = download_from_google_docs(file_list[file_name])
      upload_to_dropbox(file_name, contents)
    }
  end
end

instance = GoogleDocumentsBackup.new()
instance.main()
