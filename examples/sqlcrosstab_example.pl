#!/usr/bin/perl -w
use strict;
use DBI;
use DBIx::SQLCrosstab::Format;
use Data::Dumper;

my $dbh;

my $driver = shift || 'SQLite';

if ($driver eq 'SQLite') {
    $dbh = DBI->connect("dbi:SQLite:xtab.sqlite",
    "","",{RaiseError=>1, PrintError=> 0 });
} 
elsif($driver eq 'mysql') {
    # Adjust host, username, and password according to your needs
    $dbh = DBI->connect("dbi:mysql:xtab; host=localhost"
	    . ";mysql_read_default_file=$ENV{HOME}/.my.cnf"  # only Unix. Remove this line for Windows
        ,  undef,  # username
           undef,  # password
          {RaiseError=>1, PrintError=> 0 }) 
}
else {
    die "You need a connection statement for driver <$driver>\n";
}
$dbh or die "Error in connecton [ driver $driver ] ($DBI::errstr)\n";

my $params = {
    dbh            => $dbh, 
    op             => 'sum',    # try also COUNT or AVG
    op_col         => 'salary', 
    title          => 'TBD',
    add_op         => [],
    title_in_header=> 1,
    remove_if_null => 1,        # remove columns with all nulls
    remove_if_zero => 1,        # remove columns with all zeroes
    add_colors     => 1,        # distinct colors for string and numbers
    add_real_names => 1,        # real column name as comment in query
    col_total      => 1,
    col_sub_total  => 1,
    row_total      => 1,
    row_sub_total  => 1,
    commify        => 1,        # add thousand separating commas in numbers
    rows           => 
        [       
         { col => 'CASE WHEN country="Italy" THEN "S" ELSE "N" END', alias => 'Area' },
         { col => 'country'},
         { col => 'loc',     alias => 'location' }
        ],
    cols           => 
        [
         { 
           id    => 'dept_id', 
           value => 'dept',     
           from  => 'depts' 
         },
         { 
           id    => 'cat_id',  
           value => 'category', 
           from  => 'categories' 
         },
         { 
           id       => 'gender',   
           col_list => [ {id=>'f'}, {id =>'m'}],
           from     => 'person' 
         },
        ],

    from           => 
        qq{person 
            INNER JOIN locs ON (person.loc_id=locs.loc_id) 
            INNER JOIN countries ON (countries.country_id=locs.country_id)
            },
};
    
my $fname = 'table';

$params->{title} =  "personnel by "
        . (join "/", map {exists $_->{alias} ? 
                        $_->{alias} : $_->{col}} @{$params->{rows}} )
        . " and "
        . (join "/", map {exists $_->{value} ? 
                        $_->{value} : $_->{id}} @{$params->{cols}} );

my $xt = DBIx::SQLCrosstab::Format->new($params) 
    or die "$DBIx::SQLCrosstab::errstr\n";    

my $query = $xt->get_query ('#') 
    or die "$DBIx::SQLCrosstab::errstr\n";    

my $recs = $xt->get_recs
    or die "$DBIx::SQLCrosstab::errstr\n"; 

# 
# create a html example
# 
open HTML, ">$fname.html" 
    or die "can't create $fname.html\n";
print HTML  $xt->html_header; 
print HTML  "<h3>",$xt->op, 
            "(", $xt->op_col, ") ", 
            $params->{title}, "</h3>";

my $table = $xt->as_html;
$table =~ s/\bzzzz\b/total/g;
print HTML $table;
my $bare_table = $xt->as_bare_html;
$bare_table =~ s/\bzzzz\b/total/g;
print HTML "<p></p>\n",$bare_table;
print HTML $xt->html_footer;
close HTML;
print "$fname.html created\n";

# 
# create a xml example
# 
my $xml = $xt->as_xml 
    or die "$DBIx::SQLCrosstab::errstr";
open XML, ">$fname.xml" 
    or die "can't create $fname.xml";
print XML $xml;
close XML;
print "$fname.xml created\n";

# 
# create a xls example (requires Spreadsheet::WriteExcel)
# 
if ( $xt->as_xls("$fname.xls", "both") ) {
    print "$fname.xls created\n";
}
else {
    print "$DBIx::SQLCrosstab::errstr\n";
}

# 
# create a csv example
# 
open CSV, ">$fname.csv" 
    or die "can't create $fname.csv\n";
my $csv = $xt->as_csv('header')
    or die "$DBIx::SQLCrosstab::errstr\n";
print CSV $csv;
close CSV;
print "$fname.csv created\n";

# 
# create a yaml example
# 
open YAML, ">$fname.yaml" 
    or die "can't create $fname.yaml\n";
my $yaml = $xt->as_yaml;
if ($yaml) {
     print YAML $yaml;
}
else {
     print "$DBIx::SQLCrosstab::errstr\n";
}
close YAML;
print "$fname.yaml created\n" if $yaml;

# 
# create a sample of generated Perl structures
# 
open STRUCT, ">$fname.pl" 
    or die "can't create $fname.pl\n";
local $Data::Dumper::Indent=1;
print STRUCT Data::Dumper->Dump( [$xt->as_perl_struct('loh'),
      $xt->as_perl_struct('losh'),
      $xt->as_perl_struct('hoh')], ['loh','losh','hoh']);
close STRUCT;
print "$fname.pl created\n";
