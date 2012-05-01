OC Transpo data access service
==============================

This is a web service that provides access to OC Transpo's data.


Getting started
---------------

1) Install RVM (Ruby Version Manager). This program allows you to easily install a particular version of Ruby, and 
switch between them if you have more than one installed. Follow the instructions at 
http://beginrescueend.com/rvm/install/ to install the latest release from Git. Don't use sudo, so it will install in 
~/.rvm

2) Install Ruby 1.9.2 and set it as the default. This means that from now on, running "ruby" from the command line will use 
Ruby 1.9.2 rather than the one that ships with OS X.

  rvm install 1.9.2
  rvm use 1.9.2 --default  # optional; if you don't do this, you'll have to run "rvm use 1.9.2" each time you start a new shell 

3) Install the Gem Bundler. Rails applications have a Gemfile which list their dependencies. Bundler ensures that these
dependencies are met when the application starts, and makes sure that the application uses the proper versions of all
the libraries it depends on.

  gem install bundler

4) Install all dependencies

  bundle install

5) Start the service

  foreman start


Updating the data files
-----------------------

1) Download OC Transpo's data from

  http://ottawa.ca/online_services/opendata/info/transit_schedule_en.html

2) Extract the `google_transit.zip` file into `data`, overwriting the files in the `google_transit` directory

3) Follow steps 1-4 in the Getting started section

4) Delete the existing database

  rm data/processed.sqlite3

4) Run the data processor to regenerate the `data/processed.sqlite3` database

  ruby data_processor.rb

Note that there's no `bundle exec` here because of a silly incompatibility between two gems. This will take a bit to 
run. There's a lot of data. It will print its status as it goes ("Dumping data at index...") every 50,000 stop times. 
There are about 1,800,000 entries total.

5) If the service is running, then restart it so it uses the updated data.

6) You should commit the updated data to Git.
