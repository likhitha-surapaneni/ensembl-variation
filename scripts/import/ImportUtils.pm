use strict;
use warnings;

package ImportUtils;

use Exporter;

our @ISA = ('Exporter');

our @EXPORT_OK = qw(dumpSQL debug create_and_load load column_exists table_exists);

#our $TMP_DIR = "/ecs2/scratch3/dani";
#our $TMP_DIR = "/ecs2/scratch4/yuan/zfish/new_snpdb";
our $TMP_DIR = "/acari/work4/yuan/HAP/hapmap/tmp";
our $TMP_FILE = 'tabledump.txt';


# successive dumping and loading of tables is typical for this process
# dump does effectively a select into outfile without server file system access
sub dumpSQL {
  my $db  = shift;
  my $sql = shift;
  local *FH;
  my $counter = 0;
  open FH, ">$TMP_DIR/$TMP_FILE";

#not necessary any more since increased the timeout of the mysql server
#  while (!$db->ping()){
#      print STDERR "Lost connection, trying to reconnect\n";
#      sleep(5);
#      $counter++;
#      if ($counter == 5) {die "Couldn't reconnect to the database\n"}
#  };
  my $sth = $db->prepare( $sql);
  $sth->{mysql_use_result} = 1;
  $sth->execute();
  my $first;
  while ( my $aref = $sth->fetchrow_arrayref() ) {
    my @a = map {defined($_) ? $_ : '\N'} @$aref;
    print FH join("\t", @a), "\n";
  }

  close FH;

  $sth->finish();
}



# load imports a table, optionally not all columns
# if table doesnt exist, create a varchar(255) for each column
sub load {
  my $db = shift;
  my $tablename = shift;
  my @colnames = @_;

  my $cols = join( ",", @colnames );

  my $table_file = "$TMP_DIR/$tablename\_$$\.txt";
  rename("$TMP_DIR/$TMP_FILE", $table_file);
   
#  my $host = $db->host();
#  my $user = $db->user();
#  my $pass = $db->pass();
#  my $port = $db->port();
#  my $dbname = $db->dbname();

#  my $call = "mysqlimport -c $cols -h $host -u $user " .
#    "-p$pass -P$port $dbname $TMP_DIR/$tablename.txt";

#  system($call);

#  unlink("$TMP_DIR/$tablename.txt");


##### Alternative way of doing same thing
  my $sql;

   if ( @colnames ) {

     $sql = qq{
               LOAD DATA LOCAL INFILE '$table_file'
               INTO TABLE $tablename( $cols )
              };
   } else {
     $sql = qq{
               LOAD DATA LOCAL INFILE '$table_file'
               INTO TABLE $tablename
              };
   }

   $db->do( $sql );

   unlink( "$table_file" );
}


#
# creates a table with specified columns and loads data that was dumped
# to a tmp file into the table.
#
# by default all columns are VARCHAR(255), but an 'i' may be added after the
# column name to make it an INT.  Additionally a '*' means add an index to
# the column.
#
# e.g.  create_and_load('mytable', 'col0', 'col1 *', 'col2 i', 'col3 i*');
#

sub create_and_load {
  my $db = shift;
  my $tablename = shift;
  my @cols = @_;

  #$db->do ("DROP TABLE $tablename") if (table_exists($db,$tablename)) ;
  my $sql = "CREATE TABLE $tablename ( ";

  my @col_defs;
  my @idx_defs;
  my @col_names;

  foreach my $col (@cols) {
    my ($name, $type) = split(/\s+/,$col);
    push @col_names, $name;

    if(defined($type) && $type =~ /i/) {
      push @col_defs, "$name INT";
    } else {
      push @col_defs, "$name VARCHAR(255)";
    }

    if(defined($type) && $type =~ /\*/) {
      push @idx_defs, "KEY ${name}_idx($name)";
    }
  }

  my $create_cols = join( ",\n", @col_defs, @idx_defs);


  $sql .= $create_cols.")";

  $db->do( $sql );

  load( $db, $tablename, @col_names );
}


sub debug {
  print STDERR @_, "\n";
}

sub table_exists{

  my $db = shift;
  my $tablename = shift;

  eval $db->do ("select count(*) from $tablename");
						
  if (! $db->errstr) {
    print "$tablename is exist return 1\n";
    return 1;
  }
  else {
    print "$tablename is not exist return 0 and will create one\n";
    return 0;
  }
}

sub column_exists{

  my $db = shift;
  my $tablename = shift;
  my $col_name = shift;

  eval $db->do ("select $col_name from $tablename limit 1");

  if (! $db->errstr) {
    print "$col_name is exist return 1\n";
    return 1;
  }  
  else {
    print "$col_name is not exist return 0 and will create one\n";
    return 0;
  }
}

1;
