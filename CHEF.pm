#
# Package Definition
#

package Data::CHEF;

#
# Perl Options
#

use strict;

#
# Includes
#

#
# Global Variables
#

use vars qw/$VERSION /;

$VERSION=0.99;

#
# Constructor Method
#

sub new
{
my ($class)=@_;
my ($object)={};
bless ($object,$class);
$object->_init();
return($object);
}

sub read
{
my ($self)=shift;
my ($line,$key,$value,$subline,$prefix,$eoi,@input,$preline);
my (@preinput)=@_;
while (@preinput)
{
	$preline=shift(@preinput);
	push(@input,split(/\n/,$preline));
}
my (@stack);
while (@input)
{
	$line=shift(@input);
	$line=~s/^\s+//;
	next if ($line=~/^#/);
	if ($line =~/==/)
	{
		($key,$value)=split(/==/,$line);
		#chop($value);
		if (@stack)
		{
			$key=$stack[$#stack].".".$key;
		}
		if ($self->{data}->{$key})
		{
			$self->{data}->{$key}.=$value
		} else {
			$self->{data}->{$key}=$value;
		}
	} elsif ($line=~/=>/)
	{
		($key,$eoi)=split(/=>/,$line);
		if (@stack)
		{
			$key=$stack[$#stack].".".$key;
		}
		$value="";
		while($subline=shift(@input))
		{
			$subline=~s/^\s+//;
			last if ($subline eq $eoi);
			$value.=$subline."\n";
		}
		if ($self->{data}->{$key})
		{
			$self->{data}->{$key}.=$value
		} else {
			$self->{data}->{$key}=$value;
		}
	} elsif ($line=~/=\{/)
	{
		($prefix)=split(/=\{/,$line);
		if (@stack)
		{
			$prefix=$stack[$#stack].".".$prefix;
		}
		push(@stack,$prefix);
	} elsif ($line eq "}")
	{
		pop(@stack);
	}
}
$self->_index();
return;
}

sub readHash
{
my ($self)=shift;
my (%hash)=@_;
my ($k);
foreach $k (keys(%hash))
{
	$self->{data}->{$k}=$hash{$k};
}
$self->_index();
return;
}

sub writeStream
{
my ($self)=shift;
my ($output)="";
my ($field,$eoi,@keys);
(@keys)=$self->keys();
foreach $field (@keys)
{
	if ($self->{data}->{$field}=~/\n/)
	{
		$eoi=$self->_randEOI($self->{data}->{$field});
		$output.=$field."=>".$eoi."\n".
			$self->{data}->{$field}."<".$eoi;
	} else {
		$output.=$field."==".$self->{data}->{$field}."\n";
	}
}
return($output);
}

sub keys
{
my ($self)=shift;
return(sort(keys(%{$self->{data}})));
}

sub get
{
my ($self)=shift;
if (scalar(@_) > 1)
{
	my ($key,%hash);
	foreach $key (@_)
	{
		$hash{$key}=$self->{data}->{$key};
	}
	return(%hash);
} else {
	my ($key)=shift;
	return $self->{data}->{$key};
}
}

sub set
{
my ($self)=shift;
my ($key,$value,$reindex);
while (@_)
{
	($key,$value)=splice(@_,0,2);
	$reindex=1 unless ($self->{data}->{$key});
	$self->{data}->{$key}=$value;
}
if ($reindex)
{
	$self->_index();
}
return;
}

sub dump
{
my ($self)=shift;
return(%{$self->{data}});
}

sub copy
{
my ($self)=shift;
my ($subkey)=shift;
my (@list,$shop);
(@list)=$self->_childKeys($subkey);
$shop=ref($self)->new();
$shop->readHash($self->get(@list));
return($shop);
}

sub spawn
{
my ($self)=shift;
my ($subkey)=shift;
my ($skf,$key,$new,@list);
(@list)=$self->_childKeys($subkey);
$skf=ref($self)->new();
foreach $key (@list)
{
	$new=_chopKey($key,$subkey);
	$skf->set($new,$self->get($key));
}
return($skf);
}

sub spawnArray
{
my ($self)=shift;
my ($subkey)=shift;
my ($skf,$key,$rest,$test,$index,$new,$element,@list,@array,@processed);
(@list)=$self->_childKeys($subkey);
foreach $key (@list)
{
	$new=_chopKey($key,$subkey);
	($test,$rest)=split(/\./,$new,2);
	print("DEBUG2: $new ** $test ** $rest\n");
	if ($test =~ /\((\d+)\)/)
	{
		$index=$1;
		unless ($array[$index])
		{
			print("Creating index $index\n");
			$array[$index]=ref($self)->new();
			$array[$index]->set("_array.index",$index);
		}
		$array[$index]->set($rest,$self->get($key));
		print("DEBUG:",$rest,"--",$array[$index]->get($rest),"\n");
	}
}
print("DEBUG3:",@array,"\n","IREF:",ref($array[1]),"\n");
foreach $element (@array)
{
	push(@processed,$element) if (ref($element));
}
return(@processed);
}

sub current
{
my ($self)=shift;
my ($pos);
$pos=$self->{index}->[$self->{ptr}];
return($pos,$self->{data}->{$pos});
}

sub next
{
my ($self)=shift;
unless ($self->{ptr}==$#{$self->{index}})
{
	$self->{ptr}++;
}
return;
}

sub prev
{
my ($self)=shift;
unless ($self->{ptr}==0)
{
	$self->{ptr}--;
}
return;
}

#
# Hidden Methods
#

sub _init
{
my ($self)=shift;
return;
}

sub _index
{
my ($self)=shift;
my (@keys);
(@keys)=sort(keys(%{$self->{data}}));
$self->{index}=[ @keys ];
$self->{ptr}=0;
return;
}

sub _randEOI
{
my ($self)=shift;
my ($value)=shift;
my ($eoi,$count);
do {
	$count=2;
	$eoi="";
	while ($count)
	{
		$eoi.=chr(int(rand(26))+97);
		$count--;
	}
	$count=3;
	while ($count)
	{
		$eoi.=int(rand(10));
		$count--;
	}
} until ($eoi ne $value);
return($eoi);
}

sub _childKeys
{
my ($self)=shift;
my ($substr)=shift;
$substr="^".quotemeta($substr);
my ($k,@list);
foreach $k ($self->keys())
{
	if ($k =~ /$substr/)
	{
		push(@list,$k);
	}
}
return(@list);
}

sub _chopKey
{
my ($key,$parent)=@_;
my ($child);
$parent="^".quotemeta($parent.".");
$child=$key;
$child=~s/$parent//;
return($child);
}

#
# Exit Block
#
1;

__END__

#
# POD Documentation
#

=head1 NAME

Data::CHEF Complex Hash Export Format

=head1 SYNOPSIS

SYNOPSIS

use Data::CHEF;

$shop=Data::CHEF->new();

$shop->read(@text_array);

$shop->readHash(%hash_table);

$shop->set("name.first" => "John Public");

$shop->get("name.first", "name.last");

=head1 DESCRIPTION

CHEF is a text format of a hash data structure that can be interchanged 
between programs.  Data::CHEF is designed to read and write the CHEF format.
The CHEF format can handle multiline records, hierarchial keys, and arrays.

All access is performed by object methods.  You can get/set values, perform 
basic hash operations, dump partial structures,  and traverse 
the key (similar to how an snmp MIB is walked).

=head1 DATA FORMAT

A simple key/value record is expressed like this:

 [key]==[value]

A key/value pair where the value spans multiple lines can be expressed like this:

 [key]=>END_TAG
 [value]
 [value]
 END_TAG

Whitespace at the start of a line is ignored.

The keys in the CHEF format can be hierarchial, with levels of the hierarchy 
seperated by periods.

 name.first==Chris
 name.last==Josephes

Each portion of the key is known as a segment.

To reduce file size, hierarchial records in the CHEF format can be grouped 
together so the full path of the key doesn't need to be entered for every 
record.

Here is the above example compressed:

 name={
   first==Chris
   last==Josephes
 }

A key segment is capable of being an array index.  This is useful for serializing 
data, or if you are dealing with multiple records of identical data.  This 

The following is an example of array indexes being used in a CHEF file that 
contains data about a Compact Disc.

 cd.title==Pump
 cd.artist==Aerosmith
 cd.list={
	(1).track==1
	(1).index==1
	(1).title==Young Lust
 < ..... >
	(5).track==5
	(5).index==1
	(5).title==Water Song
	(6).track==5
	(6).index==2
	(6).title==Janie's Got A Gun
 < ..... >
 }

=head1 USING THE CHEF FORMAT 

Comments in a chef file can be indicated with a pound sign at the start
of the line.

Whitespace at the beginning of all lines is removed, so you can't have 
whitespace in the name of a key, nor at the start of a line for a multiline 
value.

If you're sending CHEF data in a MIME encapsulated document, use the 
MIME type "x-application/x-chef".

=head1 EXAMPLE RECORD

Here is an example record that uses every aspect of the CHEF format:


 # This is all data on John Q Public
 name.first==John
 name.last==Public
 loc={
        address=>EOA_MARKER
        1313 Mockingbird Lane
        Apartment 5
        EOA_MARKER
        state==Minnesota
        locality==Young America
        zip==55555
 }
 phone={
         (1)={    
                 number==320.555.1212
                 label==Home
         }
         (2)={
                 number==320.555.2121
                 label==Work
         }
 }                 
 inet={           
         email.(1).address==jqp@ci.young-america.mn.us
 }

For convenience, all code examples below are based on this example input.

=head1 METHODS

=over 4 

=item $shop=Data::CHEF->new();

Create a new CHEF object

=item $shop->read(@text_array);

Read in text from an array to populate the internal data structure

=item $shop->readHash(%hash_table);

Read in a hash table using the same keys and values to populate the data structure

=item $string=$shop->write();

Send the structure out as a single stream that can be written to a file

=item $shop->keys();

Return an array of all keys in the structure

=item $shop->dump();

Return a hash of all keys and values in the structure

=item $shop->get(@key_list);

Return the value for a specific key.  If 1 key is specified, that key value 
is returned.  If multiple keys are specified, the requested keys AND values are 
returned as a hash.

=item $shop->set(%hash);

Set specific keys and values in the structure

=item $shop->current();

Return the current key and value where the index pointer is

=item $shop->next();

Move the index pointer up one key

=item $shop->prev();

Move the index pointer back one key

=item $shop->copy($base_key)

Creates a new CHEF object with keys that match the base_key.  For instance, 
with the example above and a $base_key of "name", it would create a CHEF 
object with only 2 keys/values: name.first and name.last

=item $shop->spawn($base_key);

Creates a new CHEF object with keys like copy, but removes the base_key portion 
of the names in the new keys.  For instance, with a $base_key of "loc" with the 
same example, a new CHEF object would be created with 4 key/value pairs: 
address, state, locality, zip.

=item $shop->spawnArray($base_key);

Creates an array of CHEF objects when the base key points to an array structure.  
If $base_key was "phone", an array of CHEF objects would be returned, each one 
containing the keys: number and label.

=back

=head1 AUTHOR

Chris Josephes		chrisj@mr.net

=head1 VERSION

Version 0.99
