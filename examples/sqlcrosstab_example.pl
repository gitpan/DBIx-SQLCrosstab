#!/usr/bin/perl -w
use strict;
use DBI;
use DBIx::SQLCrosstab 1.15;
use DBIx::SQLCrosstab::Format 0.06;
use Data::Dumper;

my $dbh;

my $driver = shift || 'SQLite';

if ($driver eq 'SQLite') {
    $dbh = DBI->connect("dbi:SQLite:crosstab.sqlite",
    "","",{RaiseError=>1, PrintError=> 0 });
} 
elsif($driver eq 'mysql') {
    # Adjust host, username, and password according to your needs
    $dbh = DBI->connect("dbi:mysql:crosstab; host=localhost"
	    . ";mysql_read_default_file=$ENV{HOME}/.my.cnf"  # only Unix. Remove this line for Windows
        ,  undef,  # username
           undef,  # password
          {RaiseError=>1, PrintError=> 0 }) 
}
else {
    die "You need a connection statement for driver <$driver>\n";
}
$dbh or die "Error in connection [ driver $driver ] ($DBI::errstr)\n";

my $params = {
    dbh            => $dbh, 
    op             => 'SUM',    
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
           value => 'department',     
           from  => 'departments' 
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
            INNER JOIN locations 
                ON (person.loc_id=locations.loc_id) 
            INNER JOIN countries 
                ON (countries.country_id=locations.country_id)
            },
};
    
$params->{title} =  "personnel by "
        . (join "/", map {exists $_->{alias} ? 
                        $_->{alias} : $_->{col}} @{$params->{rows}} )
        . " and "
        . (join "/", map {exists $_->{value} ? 
                        $_->{value} : $_->{id}} @{$params->{cols}} );

my $xtab1 = DBIx::SQLCrosstab::Format->new($params) 
    or die "$DBIx::SQLCrosstab::errstr\n";    

my $query = $xtab1->get_query ('#') 
    or die "$DBIx::SQLCrosstab::errstr\n";    

my $recs = $xtab1->get_recs
    or die "$DBIx::SQLCrosstab::errstr\n"; 

#
# Using the alternative params setting
#

#
# First, create a dummy object
#
my $xtab2 =  DBIx::SQLCrosstab::Format->new('STUB')
            or die "error in object creation ($DBIx::SQLCrosstab::errstr)\n";
    
#
# Then, pass parameters to it. You can do it one-by-one
#
$xtab2->set_param( dbh => $dbh )
    or die "error adding mandatory parameters ($DBIx::SQLCrosstab::errstr)";
            
#
# Or several ones at once
#
$xtab2->set_param( 
   op      => 'SUM',
   op_col  => 'sale_amount',
   rows    => [       
                #{ col     => 'loc', alias => 'location'},
                { col     => 'customer' },
                #{ col     => 'class_name', alias =>'class'}
              ],
   cols    => [
                {
                    id    => 'country_id',
                    value => 'country',
                    from  => 'countries'
                },
                { 
                    id    => 'person.person_id', 
                    value => 'name',     
                    from  => 'person' 
                },
                { 
                    id    => 'class.class_id',   
                    value => 'class_name',     
                    from  => 'class' 
                },
              ],
  from    => 
              qq{sales 
                  INNER JOIN customers 
                      ON (sales.customer_id=customers.customer_id) 
                  INNER JOIN person 
                      ON (sales.person_id=person.person_id)
                  INNER JOIN class 
                      ON (sales.class_id=class.class_id)
                  INNER JOIN locations 
                      ON (locations.loc_id=person.loc_id)
                  },
)
    or die "error adding mandatory parameters ($DBIx::SQLCrosstab::errstr)";

$xtab2->set_param( 
  title          => 'Sales',
  remove_if_null => 1,
  remove_if_zero => 1,
  use_real_names => 1,
  add_colors     => 1,
  col_total      => 1,
  col_sub_total  => 1,
  row_total      => 1,
  row_sub_total  => 1,
  commify        => 1,
  table_border   => 3,
  header_color   => "#009999",
  text_color     => "#3399cc",
  number_color   => "#ff00ff",
  footer_color   => "#33cc33",
)
    or die "error adding optional parameters ($DBIx::SQLCrosstab::errstr)";

#
# Check that everything is OK. 
# Alternatively, you can save the query and the recordset
# to a variable for further use
#
unless ($xtab2->get_query and $xtab2->get_recs) {
    die "$DBIx::SQLCrosstab::errstr";
}

#
# Save the current parameters to a file
#
$xtab2->save_params("xtab2.pl") or die "$DBIx::SQLCrosstab::errstr";

#
# Create a third object
#
my $xtab3 = DBIx::SQLCrosstab::Format->new('STUB')
    or die "error in object creation ($DBIx::SQLCrosstab::errstr)\n";

#
# Use the saved parameters to set it up
#
$xtab3->load_params("xtab2.pl") or die "$DBIx::SQLCrosstab::errstr";
$xtab3->set_param( dbh => $dbh) or die "$DBIx::SQLCrosstab::errstr";

unless ($xtab3->get_query and $xtab3->get_recs) {
    die "$DBIx::SQLCrosstab::errstr";
}

my $fname = 'table00';

for my $xt (($xtab1, $xtab2, $xtab3)) {
    $fname++;
    # 
    # create a html example
    # 
    open HTML, ">$fname.html" 
        or die "can't create $fname.html\n";
    print HTML  $xt->html_header; 
    print HTML  "<h3>",$xt->op, 
                "(", $xt->op_col, ") ", 
                $xt->{title}, "</h3>";

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
}

print "\nNotice that, since \$xtab3 is a clone of \$xtab2,\n",
       "table02* and table03* must be have the same contents.\n";

