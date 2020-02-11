
# Copyright 2009, 2020 University Of Helsinki (The National Library Of Finland)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package Aleph::UserInfo;

use 5.008000;
use strict;
use warnings;
use DBI;

our $VERSION = '1.03';

	
sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;

	my $self = { config => $_[0], users => {} };

	#Check the configs

	if (!defined($self->{config}->{'aleph-server'})) { die("$0: Missing config attribute: 'aleph-server'"); }
	if (!defined($self->{config}->{'aleph-user'})) { die("$0: Missing config attribute: 'aleph-user'"); }
	if (!defined($self->{config}->{'aleph-pass'})) { die("$0: Missing config attribute: 'aleph-pass'"); }		
	if (!defined($self->{config}->{'user_library'})) { die("$0: Missing config attribute: 'user_library'"); }	
	
	
	
	return bless($self,$class);
}

#true if user exists, false otherwise.
sub exists() {
	my $self = shift;
	my $user = trim(uc(shift));
	if (!defined($self->{users}->{$user})) {
		$self->loadSingleUser($user)
		or return 0; 
	}
	return 1;
}


#Returns the full name of user.
sub getUserName() {
	my $self = shift;
	my $user = trim(uc(shift));
	if (!defined($self->{users}->{$user})) {
		$self->loadSingleUser($user)
		 or return undef; 
	}
	
	return $self->{users}->{$user}->{FULLNAME};
}


#Returns the department of user.
sub getLibrary() {
	my $self = shift;
	my $user = trim(uc(shift));
	if (!defined($self->{users}->{$user})) {
		$self->loadSingleUser($user)
		 or return undef; 
	}
	
	return $self->{users}->{$user}->{LIBRARY};
}


#Returns the email address of user.
sub getEmail() {
	my $self = shift;
	my $user = trim(uc(shift));
	if (!defined($self->{users}->{$user})) {
		$self->loadSingleUser($user)
		 or return undef; 
	}
	
	return $self->{users}->{$user}->{EMAIL};
}


#Returns the last login date of user.
sub getLoginDate() {
	my $self = shift;
	my $user = trim(uc(shift));
	if (!defined($self->{users}->{$user})) {
		$self->loadSingleUser($user)
		 or return undef; 
	}
	
	return $self->{users}->{$user}->{LOGINDATE};
}

sub getCatalogProxy() {
	my $self = shift;
	my $user = trim(uc(shift));
	if (!defined($self->{users}->{$user})) {
		$self->loadSingleUser($user)
		 or return undef; 
	}
	
	return $self->{users}->{$user}->{CPROXY};
}


#Return the list of libraries
sub getLibraryList() {
	my $self = shift;
	
	my $config = $self->{'config'};

	if (!defined($self->{librarylist})) {
	
my $sql = << "END";
select distinct(Z66_DEPARTMENT) as LIBRARIES
from $config->{'user_library'}.z66
END


	my $dbh = $self->getDBHandle();
	my $sth = $dbh->prepare($sql);
	if (!$sth) {
		print STDERR "Couldn't prepare statement: " . $dbh->errstr;
		return undef;
	}

	$sth->execute();
	
	my @libraries;
	while (my $data = $sth->fetchrow_hashref()) {
		if (defined($data->{LIBRARIES})) {
			push(@libraries, $data->{LIBRARIES});
		}
	}
	$self->{librarylist} = \@libraries;
	}
	
	return $self->{librarylist};
}

#returns the config hash
sub config() {
	my $self = shift;
	return $self->{'config'};
}


#loads single user to cache.
#If you need info about multiple/all users, then you should use loadAllUsers() to load them all into cache at once.
sub loadSingleUser() {

	my $self = shift;
	my $username = shift;
	my $config = $self->{'config'};

my $sql = << "END";
select 
Z66_REC_KEY as USERNAME, 
Z66_NAME as FULLNAME, 
Z66_DEPARTMENT as LIBRARY, 
Z66_EMAIL as EMAIL, 
Z66_FUNCTION_PROXY, Z66_CATALOG_PROXY as CPROXY, 
Z66_LAST_LOGIN_DATE AS LOGINDATE, 
Z66_BLOCK as BLOCKED
from $config->{'user_library'}.z66
where Z66_REC_KEY = ?
END


	my $dbh = $self->getDBHandle();
	my $sth = $dbh->prepare($sql);
	if (!$sth) {
		print STDERR "Couldn't prepare statement: " . $dbh->errstr;
		return undef;
	}
	
	$sth->bind_param(1,$username,DBI::SQL_CHAR);
	
	$sth->execute();
	
	if (my $data = $sth->fetchrow_hashref()) {
		$self->{users}->{trim($data->{USERNAME})} = $data;
		return 1;
	}

	return undef;
}

#loads all users to cache.
sub loadAllUsers() {

	my $self = shift;
	my $username = shift;
	my $config = $self->{'config'};

my $sql = << "END";
select 
Z66_REC_KEY as USERNAME, 
Z66_NAME as FULLNAME, 
Z66_DEPARTMENT as LIBRARY, 
Z66_EMAIL as EMAIL, 
Z66_FUNCTION_PROXY, Z66_CATALOG_PROXY as CPROXY, 
Z66_LAST_LOGIN_DATE AS LOGINDATE, 
Z66_BLOCK as BLOCKED
from $config->{'user_library'}.z66
END


	my $dbh = $self->getDBHandle();
	my $sth = $dbh->prepare($sql);
	if (!$sth) {
		print STDERR "Couldn't prepare statement: " . $dbh->errstr;
		return undef;
	}
		
	$sth->execute();
	
	while (my $data = $sth->fetchrow_hashref()) {
		$self->{users}->{trim($data->{USERNAME})} = $data;
	}

	return 1;
}

sub getDBHandle() {

	my $self = shift;
	if (defined($self->{'dbh'})) {
		return $self->{'dbh'};
	}
	
	my $config = $self->{'config'};
	
	my ($host,$userid,$pwd) = ($config->{'aleph-server'},$config->{'aleph-user'},$config->{'aleph-pass'});
#	$host = $host . ":1521";
	my $dbh = DBI->connect($host,$userid,$pwd);
	if (!$dbh) {
		print STDERR "Couldn't connect to database:" . DBI->errstr;
		return undef;
	}
	$self->{'dbh'} = $dbh;
	return $self->{'dbh'};
}


sub DESTROY {
    my $self = shift;
		if (defined($self->{'dbh'})) {
			$self->{'dbh'}->disconnect;
		}
}

sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}


1;


__END__