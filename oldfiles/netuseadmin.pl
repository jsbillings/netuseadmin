#!/usr/um/perl5/bin/perl
################################################################################
#
# NETUSEADMIN 
#
################################################################################
# Author:  
#      Brian G. Kuhn <bgkuhn@engin.umich.edu>
#
# History:
#      1/5/96 bgkuhn: Initial release
#
################################################################################
## Copyright (C) 1996 by the Regents of the University of Michigan.
##
## User agrees to reproduce said copyright notice on all copies of the software
## made by the recipient.
##
## All Rights Reserved. Permission is hereby granted for the recipient to make
## copies and use this software for its own internal purposes only. Recipient of
## this software may not re-distribute this software outside of their own
## institution. Permission to market this software commercially, to include this
## product as part of a commercial product, or to make a derivative work for
## commercial purposes, is explicitly prohibited.  All other uses are also
## prohibited unless authorized in writing by the Regents of the University of
## Michigan.
##
## This software is offered without warranty. The Regents of the University of
## Michigan disclaim all warranties, express or implied, including but not
## limited to the implied warranties of merchantability and fitness for any
## particular purpose. In no event shall the Regents of the University of
## Michigan be liable for loss or damage of any kind, including but not limited
## to incidental, indirect, consequential, or special damages.
################################################################################
 
push(@INC, "/usr/caen/netuse/lib");
require "netuse_client.pl";

 
######################################################################
#
# Help
#
# Usage:	&Help;
#
# Purpose:  	To display command line options.
#
######################################################################
sub Help {
    print <<EOM;

--------------------------------------------------------------------------------
Commands:
 
add       <hostname> <vendor> <model> L|P  Add a new host to the database
delete    <hostname>                       Delete a host from the database
location  <hostname> [<room>] <building>   Set the location for a host
models    [<vendor>]                       List model types 
list      [<vendor>] [L|P]                 List hosts

reload                                     Load hosts from NETUSE hostfile
savestate                                  Store host list in NETUSE hostfile
use       <filename>                       Read commands from a file

?, help                                    Display this help text
exit, quit                                 Exit the program

EOM

    print "Valid vendor designations:  ", join(' ', sort(@PLATFORMS)), "\n";
    print "All commands and arguments EXCEPT hostnames are case-insensitive.\n";
    print '-'x80, "\n\n";
}


######################################################################
#
# ListModels
#
# Usage:	&ListModels($vendor);
#
# Purpose:  	To display the models for a given vendor (if specified.)
#               Otherwise, displays all vendors and all models.
#
# Arguments:    Optional vendor name
#
######################################################################
sub ListModels {
    my(@args) = grep(tr/a-z/A-Z/, @_);
    my(@plats);  

    if (@args > 1) {
	print "\nInvalid number of arguments.\n\n"; return; 
    }
    if (@args) {	              # One argument
	if ($PLATFORMS{$args[0]}) { @plats = @args; }
	else { print "\nInvalid Vendor.\n\n"; return; }
    }
    else { 
	@plats = @PLATFORMS; 
    }

    print "\n";
    foreach $_ (sort @plats) {
	print "Models for $_:\n";
	print "\t", join(", ", @{$PLATFORMS{$_}}), "\n\n";
    }
}


######################################################################
#
# Use
#
# Usage:	&Use($commandfile);
#
# Purpose:  	To open a command file and act as the main driver
#               for the execution for the commands in that file.
#
# Arguments:    Name of a command file
#
# Calls:        &Execute
#
######################################################################
sub Use {
    my(@args) = @_;
    local(*F);
    local($done);

    unless (@args == 1) {              # Make sure only one argument
	print "\nInvalid number of arguments.\n\n";
	return;
    }
    unless (open(F, "@args[0]")) {     # Open file for input
	print "\nError opening file for input.  Command aborted.\n\n";
	return;
    }

    while (<F>) {                      # Loop through file and execute
	next if /^#/;
	chomp;
	print "Executing:  $_\n";
	$done = Execute($_);
	last if $done;
    }
    close(F);
}
	    

######################################################################
#
# SendReq
#
# Usage:	&SendReq($command, @arguments);
#
# Purpose:  	To send a Netuse Administrative command to the 
#               Netuse server and to display the results of that
#               command.
#
# Arguments:    Command and arguments to that command
#
######################################################################
sub SendReq {
    local($com, @args) = @_;
    local($results, $line);            # Results of call to server

    # Send request
    $results = &NetuseRequest("NUADMIN $com " . join(' ', @args));

                                       # Special format for LiSTing
    if ($com =~ 'LST' && $results !~ /Invalid/) {  
	print "\nHost name             Type and Model       Location               Class   Status";
	print "\n--------------------  -------------------  --------------------  -------  ------\n";
	foreach $line (split("\n", $results)) {
	    @_ = split(':', $line);
	    printf("%-20s  %-5s%-14s  %-20s  %-7s  %-6s\n",
		   substr($_[0], 0, 20), @_[1,2],
		   substr($_[12], 0, 20), ($_[11] eq 'L') ? '  Lab' : 'Private', 
		   ($_[14] > time - $DOWN_INTERVAL) ? '  Up' : ' Down');
	}
	print "\n";
    }
    else {                             # Typical NUADMIN command
	print "\n$results\n";
    }
}


######################################################################
#
# Execute
#
# Usage:	$donewithsession = &Execute($commandstring);
#
# Purpose:  	To parse a command string, determine the command,
#               and to call the appropriate driver.
#
# Arguments:    The request string and the name of the remote host
#               making the request.
#
# Returns:      Boolean true if command string contains the quit
#               command... Otherwise returns false
#
# Calls:        &Help, &SendReq, &ListModels, &Use
#
######################################################################
sub Execute {
    local($line) = @_;         
    local(@args) = split(/\s+/, $line);
    local($valid) = 0;          

    $_ = shift @args;		# Get command and capitalize all letters
    tr/a-z/A-Z/;
   
    return 0 unless $_;
    return 1 if (/EXIT\b/ || /QUIT\b/);

    (/^HELP\b/ || /^\?/)   && (&Help,                  $valid++);
    /^ADD\b/               && (&SendReq('ADD', @args), $valid++);
    /^DELETE\b/            && (&SendReq('DEL', @args), $valid++);
    /^LOCATION\b/          && (&SendReq('LOC', @args), $valid++);
    /^MODELS\b/            && (&ListModels(@args),     $valid++);
    /^LIST\b/	           && (&SendReq('LST', @args), $valid++);
    /^RELOAD\b/	           && (&SendReq('REL', @args), $valid++);
    /^SAVESTATE\b/         && (&SendReq('SAV', @args), $valid++);
    /^USE\b/               && (&Use(@args),            $valid++);
    
    print "\nInvalid command.  Type '?' or 'help' to receive a list of valid commands.\n\n"
	unless $valid;

    return 0;
} 


######################################################################
#
# Main Program 
#
######################################################################
print '=' x 80, "\n";
print "Netuse Administration Command Line Interface\n";
print '=' x 80, "\n\n";

while (1) {
    print "NUADMIN>  ";
    chomp($command = <STDIN>);
    $done = &Execute($command);
    last if ($done);
}



