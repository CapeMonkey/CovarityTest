# CovarityTest

Deploy-website.ps1 is a Powershell script that Sets up a directory structure,
creates an IIS Application Pool, and creates an IIS Website. For more info, see
DevOpsScriptingChallenge.pdf

It accepts two parameters:
configFileName, a mandatory parameter indicating which file contains the 
	configurations the script wants
Teardown, an optional switch which tells the script to remove the website (and
	the app pool, if the app pool is empty) from IIS.

The config file is read by the script, treating any line with one = symbol as a
configuration variable. The required configs are:
NewWebsiteName: the name to use for the new IIS website
NewWebsiteBaseDirectoryFullPath: The path to the root directory of the new IIS 
	website. It needs to be either an existing directory or is to be created
	in an existing directory.
DirectoryDefinitionXMLFile: An XML file defining the structure of directories
	to be created. See folders.xml.
NewWebsiteLogDirectoryFullPath: The directory which should be used to log to.
	The website will still be created using the default logging directory if
	the directory cannot be created. As with 
	NewWebsiteBaseDirectoryFullPath, it wants either an existing directory
	or it is to be created in an existing directory.
NewApplicationPoolName: The name of the application pool to be created. It is
	made with an Integrated Pipeline and .Net 4.0.

An optional config is Log; if specified, it will append script specific messages
	to the specified file, otherwise it will be outputted to the console. 
	Typical Powershell output for the commands used in the script will be 
	outputted to the console whether or not this is specified.
