# RPMRequest

This is a simple sample Mac Swift program that is used to communicate with the pVelocity engine server.

## Usage

RPMRequest host_url user password [filename]

The first two parameters is used to identify the user. The optional third parameter is used to upload a file of the caller's choosing.

For example:

	RPMRequest http://localhost:8881 Admin demo /Users/kanglu/Documents/test.txt
	
## Notes

* This is not meant to be production code.
* It is just sample code for other developers to reference to communicate with the pVelocity Applicastion Server engine.