#! /usr/bin/perl -w
use File::Basename;
use File::Spec;
use DBI;
use Getopt::Long;

my $tmpMibFile="/tmp/tmpHuaweiMib";
my $tmpConfFile="/tmp/tmpHuaweiConf";
my $centFillTrapDBPath="/usr/share/perl5/vendor_perl/centreon/script/";
my $ExecFillTrapDBPath="/usr/bin/";
use POSIX qw(strftime);

sub logimport{
   my (@message)=@_;
   my $datestr=strftime "%Y-%m-%d",localtime(time());
   my $logfile = "/var/log/mibImport".$datestr.".log";   
   open(FILE, ">>$logfile");
   my $currentline =0 ;
   while ($currentline <= $#message){
     print   $message[$currentline] ;
     printf FILE $message[$currentline];
     $currentline++;
     
   }
   close (FILE);
} 


sub changeMibDecscription{
    my ($inputFile,$outputFile) = @_;
    if (!open (FILE, $inputFile))
    {
       logimport( "open MIbFile failed \n");
       exit;
    }
    my @mibfile;
    while(<FILE>)
    {
       chomp;
       s/\015//;
       push(@mibfile,$_);
    } 
    
    close(FILE) ; 
    my @newfile ;
    
    my $currentline = 0; 
    my $newtline = 0;
    while ( $currentline <= $#mibfile ){
        my $line = $mibfile[$currentline];
        if (( $line =~/(.*)\s*(?<!--)OBJECTS \{.*/ ) && (!($line =~/(.*)\s*(?<!--).*\}.*/ ))){ 
            my $tmpStr;
            for ( $i = 0; $i < 100; $i = $i + 1 )
            {  
                if (!(substr($mibfile[$currentline+1],$i,1) eq " ") && !(substr($mibfile[$currentline+1],$i,1) eq "\t"))
                {
                    $tmpStr = substr($mibfile[$currentline+1],$i);
                    last;
                }     
            }
            $newfile[$newtline] =$mibfile[$currentline].$tmpStr;
            $newtline++;
            $currentline++;
            $currentline++;
        }else 
        {
            $newfile[$newtline] = $mibfile[$currentline];
            $newtline++;
            $currentline++;
        }
    }
    
    $currentline = 0;   
    while ($currentline <= $#newfile) {     
        my $line = $newfile[$currentline];       
        if ($line =~ /(.*)\s*TRAP-TYPE.*/ ||
            $line =~ /(.*)\s*(?<!--)NOTIFICATION-TYPE.*/) { 
           
        # Make sure it doesn't start with a --.  If it does, it's a comment line..  Skip it
        if ($line =~/.*--.*TRAP-TYPE/ || $line =~/.*--.*NOTIFICATION-TYPE/) {
                # Comment line    
                $currentline++; # Increment to the next line
                $line = $newfile[$currentline]; # Get next line
                next;
        }                
        my $lineOject=0;
        my $Object='';
        my $linedecription=0;
        for( $a = 0; $a < 20; $a = $a + 1 ){
            my $templine = $newfile[$currentline+$a];
            if ($currentline > 0 && $templine =~ /^\s*OBJECTS \{(.*)\}\s*$/)
            {
                $Object =$1;
                $currentline++;
                last ; 
            }    
        }
        for( $a = 0; $a < 20; $a = $a + 1 ){
            my $templine = $newfile[$currentline+$a];
            if ($currentline > 0 && $templine =~/(.*)\s*(?<!--)DESCRIPTION.*/)
            {   
                $newfile[$currentline+$a] =~ s/\s+$//;
                my $description =  $newfile[$currentline+$a+1] ;
                $description =~ /^\s*"(.*)"\s*$/;
                $description=$1;
                $description =~ s/^\s+//;
                my @objectList=split(/,/,$Object);
                my $objectStr="";
                my $i =1;
                my @newObjectList;
                foreach $a(@objectList){
                   my $tmpStr="";
                   #print "mmm".$a."\n";
                   if (  $a =~ /.*hwTrap.*/ ){
                       #print "sss".$a;
                       $tmpStr= substr($a ,7);
                   }elsif (  $a =~ /.*hwPreciseTrap.*/ ){
                       #print "ssb".$a;
                       $tmpStr= substr($a ,14);
                   }else
                   {
                       $tmpStr =$a;
                   }
                   $tmpStr=sprintf('%s = $%d; ', $tmpStr, $i); 
                   push (@newObjectList,$tmpStr);
                   #print  "mmm ====".$objectList."\n";
                   $i++;
                }
                # foreach $a(@objectList){
                    # print  "dddd".$a.'\n';
                # }
                my $trapEvent = $newObjectList[2];
                my $trapSeq = $newObjectList[0];
                my $trapSeverity = $newObjectList[3];
                #print $newObjectList[0]."---\n";
                #print $newObjectList[3]."---\n";
                #print $trapEvent. $trapSeq.$trapSeverity ." hhhhh \n";
                $newObjectList[0] = $trapEvent;
                $newObjectList[2] = $trapSeverity;
                $newObjectList[3] = $trapSeq;
                foreach $a(@newObjectList){
                    #print "================".$a . "\n";
                    my $tmpStr="";
                    $tmpStr = $a;
                    $objectStr = $objectStr.$tmpStr;
                }
                $newfile[$currentline+$a+1] =  "				\""."\[".$description."] ".$objectStr."\"";
                $currentline++;
                last ; 
            }  
        } 
      }
       $currentline++;   
    }
    if (open (FILE, ">$outputFile"))
    {
       logimport( "clear outputFlie\n");
       
    }
    $currentline = 0;
    open(FILE, ">>$outputFile");
    while ( $currentline <= $#newfile)
    {   
         #logimport ($newfile[$currentline]);
         printf FILE $newfile[$currentline]."\n";
         $currentline++; 
    }
    close (FILE);
}

sub createExcFile{
    my ($inputFile,$outputFile) = @_;
    my $cmd =  sprintf("cp %s %s",$inputFile,$outputFile);
    system ($cmd);
    if ($? != 0 )  {
         logimport( "error , copy centFillTrapDBHW.pm failed ");
         exit;
    }
      
    if (!open (FILE, $outputFile))
    {
        logimport( "open MIbFile failed \n");
        exit;
    }
    my @oldfile=<FILE>;
    close FILE;
    foreach(@oldfile) {
        s/centFillTrapDB/centFillTrapDBHW/g;      
    }
    open FILE, ">", $outputFile or die "$!";
    print FILE @oldfile;
    close FILE;    
}
sub changLevelfile{
    my ($outputFile) = @_;
    if (!open (FILE, $outputFile))
    {
        logimport( "chang level file open MIbFile failed \n");
        exit;
    }
    my @oldfile=<FILE>;
    close FILE;
    foreach(@oldfile) {
        s/\$self\-\>\{trap\_severity\} \=\~ \/up\/i\)/\$self\-\>\{trap\_severity\} \=\~ \/normal|up\/i\)/g;
    }
     foreach(@oldfile) {
        s/\$val \=\~ \/up\/i\)/\$val \=\~ \/normal|up\/i\)/g;
    }    
    open FILE, ">", $outputFile or die "$!";
    print FILE @oldfile;
    close FILE;    
}
sub fixGetState{
    my ($outputFile) = @_;
    if (!open (FILE, $outputFile))
    {
        logimport( "fix GetState :open MIbFile failed \n");
        exit;
    }
    my @oldfile=<FILE>;
    close FILE;
    foreach(@oldfile) {
        s/\", \" . \$self\-\>getStatus\(\) \. \", \"/\", \'\" . \$self\-\>getStatus\(\) \. \"\', \"/g;
    }
    open FILE, ">", $outputFile or die "fix get statu file open fail ;error code :$!";
    print FILE @oldfile;
    close FILE;    
}

sub changConfigFile{
    my ($outputFile) = @_;
    if (!open (FILE, $outputFile))
    {
        logimport ("change config file :open MIbFile failed \n");
        exit;
    }
    my @oldfile=<FILE>;
    close FILE;
    foreach(@oldfile) {
        s/\$self\-\>\{no_desc_wildcard\} = 0/\$self\-\>\{no_desc_wildcard\} = 1/g;
    }
    open FILE, ">", $outputFile or die "changeconfige open file failed:errcod: $!";
    print FILE @oldfile;
    close FILE;    
}

sub importMibprocessNew
{        
     my ($inputmib,$vendorName) = @_;
     require "/etc/centreon/conf.pm";
     my $dbh = DBI->connect("DBI:mysql:database=".$mysql_database_oreon.";host=".$mysql_host, $mysql_user, $mysql_passwd);
     my $sth= $dbh->prepare("SELECT `id` FROM `traps_vendor` WHERE `name` = '$vendorName' ");
     $sth->execute();
     my $manufactureId = 0;
     if ($sth->rows()){
        $manufactureId = $sth->fetchrow_array();
        $sth->finish();
        $dbh->disconnect();
     }   
     else{
         logimport("can not get vendId ,please config vendor first ");
         $dbh->disconnect();
         exit ;
     }
     if (!open (FILE, $inputmib))
     {
         logimport( "check mib   open MIbFile failed \n");
         exit; 
     }
     changeMibDecscription( $inputmib ,$tmpMibFile);
     createExcFile( $centFillTrapDBPath."centFillTrapDB.pm",$centFillTrapDBPath."centFillTrapDBHW.pm");
     changConfigFile( $centFillTrapDBPath."centFillTrapDBHW.pm");
     changLevelfile( $centFillTrapDBPath."centFillTrapDBHW.pm");
     fixGetState( $centFillTrapDBPath."centFillTrapDBHW.pm");
     createExcFile( $ExecFillTrapDBPath."centFillTrapDB",$ExecFillTrapDBPath."centFillTrapDBForHW") ; 
     print "importing ,please wait \n";
     my $cmd = sprintf($ExecFillTrapDBPath."centFillTrapDBForHW -f %s -m %s",$tmpMibFile,$manufactureId);
     my @importresult=readpipe ($cmd);
     
     logimport (@importresult);

     # system ($cmd);
     # if ($? != 0 )  {
         # print "error ,import config file into DateBase failed \n";
         # exit;
     # }        
}

sub importMibprocess
{    
     my ($inputmib,$vendorName) = @_;
     #use vars qw($mysql_database_oreon $mysql_database_ods $mysql_host $mysql_user $mysql_passwd);
     require "/usr/local/centreon/etc/conf.pm";
     my $dbh = DBI->connect("DBI:mysql:database=".$mysql_database_oreon.";host=".$mysql_host, $mysql_user, $mysql_passwd);
     my $sth= $dbh->prepare("SELECT `id` FROM `traps_vendor` WHERE `name` = '$vendorName' ");
     $sth->execute();
     my $manufactureId = 0;
     if ($sth->rows()){
         $manufactureId = $sth->fetchrow_array();
         $sth->finish();
         $dbh->disconnect();
      }else{
         logimport ("can not get vendId ,please config vendor first ");
         $dbh->disconnect();
         exit ;
     }   
       
     if (!open (FILE, $inputmib))
     {
         logimport( "open MIbFile failed \n");
         exit;
     }
     $cmd = sprintf ("rm -rf ".$tmpConfFile); 
     system ($cmd); 
     
     changeMibDecscription( $inputmib ,$tmpMibFile);
     my $cmd = sprintf ("/usr/local/centreon/bin/snmpttconvertmib --in=%s --out=%s --no_desc_wildcard",$tmpMibFile,$tmpConfFile);
     #print $cmd."\n";
     print "importing ,please wait \n";
     my @snmpttresult=readpipe ($cmd);
     logimport (@snmpttresult);
     # if ($? != 0 )  {
         # logimport( "error , chang mib file snmptt config file failed ");
         # exit;
     # }  
     changLevelfile( "/usr/local/centreon/bin/centFillTrapDB" );
     print "importing ,please wait \n";
     $cmd = sprintf ("/usr/local/centreon/bin/centFillTrapDB -f %s -m %s  ",$tmpConfFile,$manufactureId);
     my @importresult=readpipe ($cmd);
     logimport (@importresult);
     # if ($? != 0 )  {
         # logimport("error ,import config file into DateBase failed ");
         # exit;
     # } 
         
}
sub main{   
    my ($imputMib,$manufacturName )= @_;
    @result = readpipe("centreon");
    if ($result[0] =~ /(.*)\s*version ([\d]+.[\d]+.[\d]+) .*/ ){   
        if ($2 eq "2.8.22")
        {
            importMibprocessNew( $imputMib, $manufacturName );
        }else{
            print "centreon vertion is not support" ;
        }
    }else{  
        system("ls /usr/local/centreon/bin/snmpttconvertmib");
        if ($? eq 0){
            importMibprocess($imputMib, $manufacturName );
        }else 
        { 
            print "check centron version failed";
        }        
    }
}

Getopt::Long::Configure('bundling');
my ($opt_f, $opt_m );
GetOptions("f|file=s" => \$opt_f, "m|man=s"  => \$opt_m );
if (!$opt_f || !$opt_m ) {
     print "importmib : Usage : perl importMib.pl -f mibFile  -m vendorName  ";
     exit;
}
main ( $opt_f ,$opt_m ) ;





