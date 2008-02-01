# 複合名詞のリストを作製するためのロジック

package mysql_hukugo;

use strict;
use Benchmark;

use kh_jchar;
use mysql_exec;
use gui_errormsg;

sub run_from_morpho{
	my $class = shift;
	my $target = $::project_obj->file_HukugoList;

	my $t0 = new Benchmark;

	# 形態素解析
	#print "1. morpho\n";
	
	my $source = $::project_obj->file_target;
	my $dist   = $::project_obj->file_m_target;
	unlink($dist);
	my $icode = kh_jchar->check_code($source);
	open (MARKED,">$dist") or 
		gui_errormsg->open(
			type => 'file',
			thefile => $dist
		);
	open (SOURCE,"$source") or
		gui_errormsg->open(
			type => 'file',
			thefile => $source
		);
	while (<SOURCE>){
		chomp;
		my $text = Jcode->new($_,$icode)->h2z->euc;
		$text =~ s/ /　/go;
		print MARKED "$text\n";
	}
	close (SOURCE);
	close (MARKED);
	kh_jchar->to_sjis($dist) if $::config_obj->os eq 'win32';
	
	$::config_obj->use_hukugo(1);
	$::config_obj->save;
	kh_morpho->run;
	$::config_obj->use_hukugo(0);
	$::config_obj->save;
	
	if ($::config_obj->os eq 'win32'){
		kh_jchar->to_euc($::project_obj->file_MorphoOut);
			my $ta2 = new Benchmark;
	}
	
	# 読み込み
	#print "2. read\n";
	mysql_exec->drop_table("rowdata_h");
	mysql_exec->do("create table rowdata_h
		(
			hyoso varchar(255) not null,
			yomi varchar(255) not null,
			genkei varchar(255) not null,
			hinshi varchar(255) not null,
			katuyogata varchar(255) not null,
			katuyo varchar(255) not null,
			id int auto_increment primary key not null
		)
	",1);
	my $thefile = "'".$::project_obj->file_MorphoOut."'";
	$thefile =~ tr/\\/\//;
	mysql_exec->do("LOAD DATA LOCAL INFILE $thefile INTO TABLE rowdata_h",1);
	
	# 中間テーブル作製
	mysql_exec->drop_table("rowdata_h2");
	mysql_exec->do("
		create table rowdata_h2 (
			genkei varchar(255) not null
		)
	",1);
	mysql_exec->do("
		insert into rowdata_h2
		select genkei
		from rowdata_h
		where
			    hinshi = \'複合名詞\'
	",1);
	
	
	# 変形
	#print "3. reform\n";
	mysql_exec->drop_table("hukugo");
	mysql_exec->do("
		CREATE TABLE hukugo (
			name varchar(255),
			num int
		)
	",1);
	mysql_exec->do("
		INSERT INTO hukugo (num, name)
		SELECT count(*), genkei
		FROM rowdata_h2
		GROUP BY genkei
	",1);
	
	# 書き出し
	#print "4. print out\n";
	open (F,">$target") or
		gui_errormsg->open(
			type => 'file',
			thefile => $target
		);
	print F "複合名詞,出現数\n";
	
	my $oh = mysql_exec->select("
		SELECT name, num
		FROM hukugo
		ORDER BY num DESC, name
	",1)->hundle;
	
	use kh_csv;
	while (my $i = $oh->fetch){

		# 日付・時刻は表示しない
		next if $i->[0] =~ /^(昭和)*(平成)*(\d+年)*(\d+月)*(\d+日)*(午前)*(午後)*(\d+時)*(\d+分)*(\d+秒)*$/;

		# 数値のみは表示しない
		my $tmp = Jcode->new($i->[0], 'euc')->tr('０-９','0-9');
		next if $tmp =~ /^\d+$/;

		print F kh_csv->value_conv($i->[0]).",$i->[1]\n";
	}
	
	close (F);
	
	kh_jchar->to_sjis($target) if $::config_obj->os eq 'win32';
	
	my $t1 = new Benchmark;
	#print timestr(timediff($t1,$t0)),"\n";
}


1;